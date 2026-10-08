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
    private let licenseKey = "sRwDAAEkY29tLm1pY3JvYmxpbmsuQmxpbmtJRERvd25sb2FkU2FtcGxlAQptaWNyb2JsaW5rhuaVr+/r/nhTn6q1K7dIj1PENbvsAqjjpbIeBU0vPlKhS79pXbdlCB65CBt/iP9nq2pX0wli+dZTcUaRwJym5SD9Q3urGj6DV88xgA9zvH1hC8eYhS9N73BF0BXDYPSMPG76CROeWhRmOmcIXKno5otU2Zh7zqqFp1c5"
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
            let settings = BlinkIDSdkSettings(licenseKey: licenseKey)
            sdkInstance = try await BlinkIDSdk.createBlinkIDSdk(withSettings: settings)
        } catch {
            state = .error(error.localizedDescription)
        }
        state = .home
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
