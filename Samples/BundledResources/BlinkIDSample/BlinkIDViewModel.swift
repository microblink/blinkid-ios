// Created by Toni Krešo on 20.3.2025.. 
// Copyright (c) 2025 Microblink Ltd. All rights reserved.

// ANY UNAUTHORIZED USE OR SALE, DUPLICATION, OR DISTRIBUTION 
// OF THIS PROGRAM OR ANY OF ITS PARTS, IN SOURCE OR BINARY FORMS, 
// WITH OR WITHOUT MODIFICATION, WITH THE PURPOSE OF ACQUIRING 
// UNLAWFUL MATERIAL OR ANY OTHER BENEFIT IS PROHIBITED! 
// THIS PROGRAM IS PROTECTED BY COPYRIGHT LAWS AND YOU MAY NOT 
// REVERSE ENGINEER, DECOMPILE, OR DISASSEMBLE IT.

import SwiftUI
import Combine
import BlinkID
import BlinkIDUX

enum UIState {
    case loading
    case home
    case scanBuiltin(BlinkIDUXModel)
    case scanCustom(CustomScanningViewModel)
    case error(String)
    case success(BlinkIDScanningResult)
}

@MainActor
final class BlinkIDViewModel: ObservableObject {
    
    // Valid until: 2027-04-06
    private let licenseKey = "sRwDAAEcY29tLm1pY3JvYmxpbmsuQmxpbmtJRFNhbXBsZQEKbWljcm9ibGlua/+x1ICxGUwNkNF+/ARNO/ted2leNDHQy6TuPaGWXV/8d/qHl83r5SJg1aoxUwAwL1n16fnt13NPC2k9PPytKKoBnVgyAX0tvKOo3D0CMvh0olsndQFDmEoZ5ot+hGj00irxeDa/Ny71+pSdoAkyArC/9d5MSehGTeMPiw=="
    private var sdkInstance: BlinkIDSdk?
    private var cancellables = Set<AnyCancellable>()
    @Published var state: UIState = .loading
    
    init() {
        Task {
            await initializeSdk()
        }
    }
    
    func initializeSdk() async {
        do {
            let resourcesConfig = ResourcesConfig(download: false, bundleUrl: Bundle.main.bundleURL)
            let otaResourcesConfig = OTAResourcesConfig(bundleUrl: Bundle.main.bundleURL)
            let settings = BlinkIDSdkSettings(licenseKey: licenseKey, resourcesConfiguration: resourcesConfig, otaResourcesConfiguration: otaResourcesConfig)
            sdkInstance = try await BlinkIDSdk.createBlinkIDSdk(withSettings: settings)
            state = .home
        } catch {
            print("BlinkID SDK initialization failed: \(error)")
            state = .error(error.localizedDescription)
        }
    }
    
    func deleteCachedResources() async {
        state = .loading
        sdkInstance = nil
        await BlinkIDSdk.terminateBlinkIDSdk()
        BlinkIDSdk.deleteCachedResources()
        await initializeSdk()
    }

    func performScan(customScan: Bool = false) async {
        guard let sdkInstance = sdkInstance
        else {
            state = .error("Failed to perform scan due to missing sdk")
            return
        }
        
        if let analyzer = try? await BlinkIDAnalyzer(sdk: sdkInstance, blinkIdSessionSettings: createSettings(), eventStream: BlinkIDEventStream()) {
            if customScan {
                let scanningUxModel = CustomScanningViewModel(analyzer: analyzer)
                scanningUxModel.$scanningResult
                    .sink { [weak self] scanningResult in
                        if let scanningResult = scanningResult {
                            self?.state = .success(scanningResult)
                        } else {
                            self?.state = .home
                        }
                    }
                    .store(in: &cancellables)
                
                state = .scanCustom(scanningUxModel)
            } else {
                let scanningUxModel = BlinkIDUXModel(analyzer: analyzer) { scanningResultState in
                    if let scanningResult = scanningResultState.scanningResult {
                        self.state = .success(scanningResult)
                    }
                    else {
                        self.state = .home
                    }
                }
                
                state = .scanBuiltin(scanningUxModel)
            }
        }
    }
    
    func createSettings() -> BlinkIDSessionSettings {
        let documentCapture = DocumentCaptureModuleSettings()
        let mrzModuleSettings = MrzModuleSettings(presenceMandatory: false)
        let vizModuleSettings = VizModuleSettings(presenceMandatory: true)
        let barcodeModuleSettings = BarcodeModuleSettings(presenceMandatory: false)
        
        let scanningSettings = ScanningSettings(
            documentCaptureModule: documentCapture,
            mrzModule: mrzModuleSettings,
            barcodeModule: barcodeModuleSettings,
            vizModule: vizModuleSettings
        )
        
        return BlinkIDSessionSettings(
            inputImageSource:          .video,
            scanningMode:              .automatic,
            scanningSettings:          scanningSettings
        )
    }
}
