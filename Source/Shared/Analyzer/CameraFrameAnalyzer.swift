//  Created by Jura Skrlec on 13.02.2025.
//  Copyright (c) Microblink. All rights reserved.
//  Modifications are allowed under the terms of the license for files located in the UX/UI lib folder.

import Foundation

public protocol ScanningResultProtocol: Sendable {
    associatedtype Result: Sendable
    nonisolated var scanResult: Result? { get }
}

/// Result of a document scanning session.
public enum ScanningResult<T: Sendable, U: Sendable>: ScanningResultProtocol {
        
    public typealias Result = T
    
    /// Scanning completed successfully with captured document data.
    case completed(T)
    /// Scanning was interrupted.
    case interrupted(U)
    /// Scanning was cancelled by the user or system.
    case cancelled
    /// Scanning has ended.
    case ended
    
    public var scanResult: T? {
        switch self {
        case .completed(let result): return result
        case .interrupted(_), .cancelled, .ended: return nil
        }
    }
}

/// Protocol for streaming events during document processing.
public protocol EventStream<Event>: Sendable {
    associatedtype Event: Sendable
    /// Asynchronous stream of UI events
    var stream: AsyncStream<[Event]> { get async }
}

/// A protocol that represents the interface to the features of Microblink's analyzer.
public protocol CameraFrameAnalyzer<Frame, Event> : Sendable {
    
    associatedtype Result: ScanningResultProtocol
    associatedtype Frame: Sendable
    associatedtype Event: Sendable
    
    /// Analyze the ``CameraFrame``
    func analyze(image: Frame) async
    
    /// Cancel ``CameraFrame`` analyzation.
    func cancel() async
    
    /// Pause ``CameraFrame`` analyzation.
    func pause() async
    
    /// Resume ``CameraFrame`` analyzation.
    func resume() async
    
    /// Restart ``CameraFrame`` analyzation.
    func restart() async throws

    /// Reset the per-step timeout back to the full duration
    func resetStepTimer() async

    /// End ``CameraFrame`` analyzation.
    func end() async
    
    /// Get analyzer result when analyzer is finished.
    func result() async -> Result
    
    /// Get stream of UI Events.
    var events: any EventStream<Event> { get }
    
    /// Duration in seconds before scanning step times out and is cancelled.
    /// If less than zero, scanning will not time out.
    var stepTimeoutDuration: TimeInterval { get async }
    
    /// Duration in seconds before scanning times out and is cancelled due to inactivity.
    /// If less than zero, scanning will not time out.
    var inactivityTimeoutDuration: TimeInterval { get async }
    
    var sessionNumber: Int { get }
}
