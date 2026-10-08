//
//  CameraFrameAnalyzer.swift
//  BlinkIDUX
//
//  Created by Jura Skrlec on 23.01.2025..
//

import Foundation
import AVFoundation
import CoreVideo

#if BLINKIDVERIFYUX
import BlinkIDVerify
#elseif BLINKIDUX
import BlinkID
#endif

import UIKit

public actor BlinkIDEventStream: EventStream {
    private let events: AsyncStream<[UIEvent]>
    private let continuation: AsyncStream<[UIEvent]>.Continuation
    
    public init() {
        var continuation: AsyncStream<[UIEvent]>.Continuation!
        self.events = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }
    
    deinit {
        self.continuation.finish()
    }
    
    public func send(_ events: [UIEvent]) {
        continuation.yield(events)
    }
    
    public var stream: AsyncStream<[UIEvent]> {
        events
    }
}

public protocol BlinkIDClassFilter {
    func classAllowed(classInfo: BlinkIDSDK.DocumentClassInfo) -> Bool
}

extension BlinkIDSDK.DocumentClassInfo {
    /// Whether the recognizer has classified anything at all.
    ///
    /// - Note: `isEmpty()` requires country, region **and** document type to be present, but most
    ///         countries have no sub-region, so it reports an empty class for a fully classified
    ///         document - a Croatian ID, for example. Class filtering must not depend on it.
    ///                                                          (18.9.2026. Jura Skrlec)
    var isClassified: Bool {
        if let countryId = country?.countryId, countryId != .none { return true }
        if let regionId = region?.regionId, regionId != .none { return true }
        if let documentTypeId = documentType?.documentTypeId, documentTypeId != .none { return true }
        return false
    }
}

/// Allows only passport booklets, and optionally narrows the result further with a
/// client provided filter.
///
/// Used when the analyzer is created with `passportOnly: true`.
struct PassportOnlyClassFilter: BlinkIDClassFilter {
    /// Passport booklets have a data page that can be opened, unlike `passportCard`.
    static let allowedDocumentTypes: Set<DocumentTypeID> = [
        .passport,
        .alienPassport,
        .consularPassport,
        .minorsPassport,
        .refugeePassport,
        .emergencyPassport,
        .temporaryPassport
    ]

    /// Client provided filter, applied only to classes that passed the passport check.
    let additionalFilter: (any BlinkIDClassFilter)?

    func classAllowed(classInfo: BlinkIDSDK.DocumentClassInfo) -> Bool {
        /// The document type can still be unresolved while the country is already known.
        /// Don't judge the class until there is a type to judge.
        guard let documentTypeId = classInfo.documentType?.documentTypeId,
              documentTypeId != .none else { return true }

        guard Self.allowedDocumentTypes.contains(documentTypeId) else { return false }
        return additionalFilter?.classAllowed(classInfo: classInfo) ?? true
    }
}

public enum BlinkIDExtractionMode: Sendable {
    case barcodeOnly, documentWithBarcode, fullDocument, documentWithMrz, passportOnly

    /// Derives the extraction mode from the resolved session settings.
    ///
    /// - Note: `passportOnly` is never derived here. It is a UX level flow which the analyzer
    ///         sets explicitly when it is created with `passportOnly: true`.
    init(sessionSettings: BlinkIDSessionSettings) {
        if sessionSettings.scanningSettings.documentCaptureModule == nil,
           sessionSettings.scanningSettings.barcodeModule != nil,
           sessionSettings.scanningSettings.mrzModule == nil,
           sessionSettings.scanningSettings.vizModule == nil {
            self = .barcodeOnly
        } else if sessionSettings.scanningSettings.documentCaptureModule != nil,
                  sessionSettings.scanningSettings.mrzModule == nil,
                  sessionSettings.scanningSettings.vizModule == nil,
                  sessionSettings.scanningSettings.barcodeModule?.presenceMandatory == true,
                  sessionSettings.scanningMode == .single {
            self = .documentWithBarcode
        } else if sessionSettings.scanningSettings.documentCaptureModule != nil,
                  sessionSettings.scanningSettings.mrzModule?.presenceMandatory == true,
                  sessionSettings.scanningSettings.vizModule == nil,
                  sessionSettings.scanningSettings.barcodeModule == nil,
                  sessionSettings.scanningMode == .single {
            self = .documentWithMrz
        } else {
            self = .fullDocument
        }
    }
}

public actor BlinkIDAnalyzer: CameraFrameAnalyzer {
    
    public typealias Event = UIEvent
    public typealias Result = ScanningResult<BlinkIDScanningResult, BlinkIDScanningAlertType>
    public typealias Frame = CameraFrame
    
    private let session: BlinkIDSession
    private let eventStream: BlinkIDEventStream
    private let translator: BlinkIDUXTranslator = BlinkIDUXTranslator()
    private var scanningDone = false
    private var paused = false
    private var resultContinuation: CheckedContinuation<Result, Never>?
    
    public private(set) var stepTimeoutDuration: TimeInterval
    public private(set) var inactivityTimeoutDuration: TimeInterval
    
    private var stepTimerTask: Task<Void, Never>?
    private var inactivityTimerTask: Task<Void, Never>?
    private var unsupportedDocumentTimerTask: Task<Void, Never>?

    private var stepTimerStartDate: Date?
    private var stepTimerInterval: TimeInterval?
    
    /// Last event batch sent to the stream; used to detect UI state changes.
    private var lastSentEvents: [UIEvent] = []
    
    private var classFilter: (any BlinkIDClassFilter)?
    private var redactionSettingsResolver: (any RedactionSettingsResolver)?

    // MARK: - Per-frame callback

    /// Registered by BlinkIDUXModel after construction. Not part of the public init.
    private var frameProcessResultCallback: (@Sendable (FrameProcessResultHandle) async -> Void)?

    /// Updated at the start of each analyze call so getLastFrame() reflects the current cycle.
    private var lastCameraFrame: CameraFrame?
    
    // MARK: -

    /// - Parameters:
    ///   - passportOnly: Restricts the flow to passport scanning. All document classes that are
    ///     not a passport booklet are rejected, and the UX guides the user to the passport data
    ///     page instead of the front side of a document.
    ///
    ///     Takes precedence over the extraction mode derived from `blinkIdSessionSettings`, and
    ///     is applied on top of `classFilter` - a class has to pass both filters to be allowed.
    ///
    ///     Whether the second passport page is requested is still governed by
    ///     `DocumentCaptureModuleSettings.passportDataPageScanOnly`.
    public init(
        sdk: BlinkIDSdk,
        blinkIdSessionSettings: BlinkIDSessionSettings = BlinkIDSessionSettings(inputImageSource: .video),
        eventStream: BlinkIDEventStream = BlinkIDEventStream(),
        passportOnly: Bool = false,
        classFilter: (any BlinkIDClassFilter)? = nil,
        redactionSettingsResolver: (any RedactionSettingsResolver)? = nil
    ) async throws {
        self.session = try await sdk.createScanningSession(sessionSettings: blinkIdSessionSettings)
        self._sessionNumber = await session.getSessionNumber()
        self._extractionMode = passportOnly
            ? .passportOnly
            : BlinkIDExtractionMode(sessionSettings: await session.getResolvedSessionSettings())
        self.eventStream = eventStream
        self.stepTimeoutDuration = blinkIdSessionSettings.stepTimeoutDuration
        self.inactivityTimeoutDuration = blinkIdSessionSettings.inactivityTimeoutDuration
        self.classFilter = passportOnly
            ? PassportOnlyClassFilter(additionalFilter: classFilter)
            : classFilter
        self.redactionSettingsResolver = redactionSettingsResolver
    }

    private let _sessionNumber: Int

    nonisolated public var sessionNumber: Int {
        return _sessionNumber
    }

    private let _extractionMode: BlinkIDExtractionMode

    nonisolated public var extractionMode: BlinkIDExtractionMode {
        return _extractionMode
    }

    // MARK: - Per-frame callback wiring

    /// Called internally by BlinkIDUXModel to register the per-frame callback.
    func setFrameProcessResultCallback(_ callback: @escaping @Sendable (FrameProcessResultHandle) async -> Void) {
        self.frameProcessResultCallback = callback
    }

    // MARK: -

    public func analyze(image: Frame) async {
        guard !paused else { return }

        // Store raw frame before processing so lastFrame() is current for this cycle.
        lastCameraFrame = image
        
        if stepTimerTask == nil {
            resumeStepTimer()
        }
        
        if inactivityTimerTask == nil {
            await startInactivityTimer(inactivityTimeoutDuration)
        }
        
        let inputImage = InputImage(cameraFrame: image)
        do {
            let frameProcessResult = try await session.process(inputImage: inputImage)
            
            if let classInfo = frameProcessResult.processResult?.inputImageAnalysisResult.documentClassInfo,
               classInfo.isClassified,
               let filter = classFilter {
                if !filter.classAllowed(classInfo: classInfo) {
                    /// - Note: scanInterrupted returns alert type in continuation which results in presenting an alert.
                    ///         Presening an alert results in paused scanning, which is resumed and reset on alert dismiss.
                    ///                                                          (4.3.2025. Toni Kreso)
                    scanInterrupted(with: .disallowedClass)
                    return
                }
            }
        
            // This needs to be tested, what if analyze image is getting a new one and this didn't finish
            // Maybe add it to task and see if task of translation is alreday in progress
            // Jura Skrlec 23.2.2026.
            let events = await translator.translate(frameProcessResult: frameProcessResult, session: session)
            
            if events.contains(.unsupportedDocument) {
                startUnsupportedDocumentScanTimer()
            } else {
                unsupportedDocumentTimerTask?.cancel()
            }
            
            if events.contains(.unparsableBarcode) {
                triggerResolveCurrentStep()
                Task {
                    if sessionNumber > 0 {
                        let pinglet = UxEventPinglet(eventType: .unsupportedbarcodetimeout)
                        await PingManager.shared.addPinglet(pinglet: pinglet, sessionNumber: sessionNumber)
                    }
                }
            }

            if events.contains(.requestDocumentSide(side: .barcode)) {
                cancelInactivityTimer()
                startStepTimer(stepTimeoutDuration)
            }
            
            if events != lastSentEvents {
                lastSentEvents = events
                await startInactivityTimer(inactivityTimeoutDuration)
            }
            
            await eventStream.send(events)
            
            if await session.getScanningStatus() == .documentScanned {
                guard !scanningDone else { return }
                scanningDone = true
                
                let classInfo = frameProcessResult.processResult?.inputImageAnalysisResult.documentClassInfo
                let resolver = self.redactionSettingsResolver
                
                Task { @ProcessingActor in
                    let redactionSettings: RedactionSettings? = {
                        guard let resolver, let classInfo, classInfo.isClassified else { return nil }
                        return resolver.resolveRedactionSettings(classInfo: classInfo)
                    }()
                    
                    let sessionResult = session.getResult(redactionSettings: redactionSettings)
                    await finishScanning(with: .completed(sessionResult))
                }
                return
            }
            
            // Invoke per-frame callback when processResult is available.
            // processResult is non-nil only when the session actively processed the frame
            // (i.e. a document was detected). Frames with no detection are skipped.
            if let callback = frameProcessResultCallback,
               let processResult = frameProcessResult.processResult {
                let capturedFrame = lastCameraFrame  // capture value, not actor reference
                let handle = FrameProcessResultHandle(
                    processResult: processResult,
                    advanceToNextStep: { [weak self] in
                        await self?.triggerResolveCurrentStep()
                    },
                    getLastFrame: {
                        guard let frame = capturedFrame else { return nil }
                        return LastFrameResult(image: self.makeUIImage(from: frame), orientation: frame.orientation)
                    },
                    triggerStepTimeout: { [weak self] in
                        Task { await self?.scanInterrupted(with: .timeout) }
                    }
                )
                await callback(handle)
            }
        } catch {
            resultContinuation?.resume(returning: .cancelled)
        }
    }

    /// Wraps session.resolveCurrentStep(). Silent no-op if already done or paused.
    private func triggerResolveCurrentStep() {
        guard !scanningDone, !paused else { return }
        Task { @ProcessingActor in
            try? session.resolveCurrentStep()
        }
        
    }
    
    private func finishScanning(with result: ScanningResult<BlinkIDScanningResult, BlinkIDScanningAlertType>) {
        cancelAllTimers()
        resultContinuation?.resume(returning: result)
        resultContinuation = nil
    }
    
    public func cancel() {
        self.session.cancelActiveProcessing()
    }
    
    public func result() async -> ScanningResult<BlinkIDScanningResult, BlinkIDScanningAlertType> {
        await withCheckedContinuation { continuation in
            self.resultContinuation = continuation
        }
    }
    
    public func pause() {
        self.paused = true
        self.cancel()
        freezeStepTimerRemaining()
        cancelAllTimers()
    }

    private func freezeStepTimerRemaining() {
        guard let startDate = stepTimerStartDate, let interval = stepTimerInterval else { return }
        stepTimerInterval = max(0, interval - Date().timeIntervalSince(startDate))
        stepTimerStartDate = nil
    }
    
    public func resume() {
        guard paused else { return }
        self.session.resumeActiveProcessing()
        paused = false
    }
    
    public func restart() throws {
        Task { @ProcessingActor in
            try self.session.reset()
        }
        translator.resetState()
        lastSentEvents = []
        cancelAllTimers()
        stepTimerStartDate = nil
        stepTimerInterval = nil
        resume()
    }

    public func resetStepTimer() {
        stepTimerTask?.cancel()
        stepTimerTask = nil
        stepTimerStartDate = nil
        stepTimerInterval = nil
        if !paused {
            startStepTimer(stepTimeoutDuration)
        }
    }
    
    public func end() {
        pause()
        resultContinuation?.resume(returning: .ended)
        resultContinuation = nil
    }
    
    nonisolated public var events: any EventStream<UIEvent> {
        eventStream
    }
    
    private func startStepTimer(_ interval: TimeInterval) {
        guard interval > 0.0 else { return }
        stepTimerTask?.cancel()
        stepTimerStartDate = Date()
        stepTimerInterval = interval
        stepTimerTask = Task() { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let nanoseconds = UInt64(interval * Double(NSEC_PER_SEC))
                try? await Task.sleep(nanoseconds: nanoseconds)
                if !Task.isCancelled {
                    await scanInterrupted(with: .timeout)
                }
            }
        }
    }


    /// Starts (or restarts) the inactivity timer.
    /// Must be called every time the UI state changes (i.e. a new distinct event batch).
    private func startInactivityTimer(_ interval: TimeInterval) async {
        guard await session.getScanningStatus() != .scanningBarcodeInProgress else { return }
        guard inactivityTimeoutDuration > 0 else { return }
        inactivityTimerTask?.cancel()
        inactivityTimerTask = Task { [weak self] in
            guard let self else { return }
            let nanoseconds = UInt64(interval * Double(NSEC_PER_SEC))
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await self.scanInterrupted(with: .inactivityTimeout)
        }
    }
    
    private func cancelAllTimers() {
        stepTimerTask?.cancel()
        stepTimerTask = nil
        inactivityTimerTask?.cancel()
        inactivityTimerTask = nil
        unsupportedDocumentTimerTask?.cancel()
        unsupportedDocumentTimerTask = nil
    }
    
    private func resumeStepTimer() {
        guard stepTimerTask == nil else { return }
        if let interval = stepTimerInterval {
            stepTimerInterval = nil
            if interval <= 0 {
                scanInterrupted(with: .timeout)
            } else {
                startStepTimer(interval)
            }
        } else {
            startStepTimer(stepTimeoutDuration)
        }
    }
    
    private func cancelInactivityTimer() {
        inactivityTimerTask?.cancel()
        inactivityTimerTask = nil
    }
    
    private func scanInterrupted(with alertType: BlinkIDScanningAlertType) {
        pause()
        resultContinuation?.resume(returning: .interrupted(alertType))
        resultContinuation = nil
        
        Task {
            if sessionNumber > 0 {
                switch alertType {
                case .timeout:
                    let pinglet = UxEventPinglet(eventType: .steptimeout)
                    await PingManager.shared.addPinglet(pinglet: pinglet, sessionNumber: sessionNumber)
                case .inactivityTimeout:
                    let pinglet = UxEventPinglet(eventType: .inactivitytimeout)
                    await PingManager.shared.addPinglet(pinglet: pinglet, sessionNumber: sessionNumber)
                default:
                    break
                }
            }
            await PingManager.shared.sendPinglets()
        }
    }
    
    private func startUnsupportedDocumentScanTimer() {
        guard unsupportedDocumentTimerTask == nil ||
              unsupportedDocumentTimerTask?.isCancelled == true else { return }
        
        unsupportedDocumentTimerTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(1.5 * 1_000_000_000))
            if !Task.isCancelled {
                await self?.scanInterrupted(with: .unsupportedDocument)
            }
        }
    }
}

extension BlinkIDAnalyzer {
    nonisolated private func makeUIImage(from frame: CameraFrame) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(frame.buffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
