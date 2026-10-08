// Created by Toni Krešo on 11.04.2025.. 
// Copyright (c) 2025 Microblink Ltd. All rights reserved.

// ANY UNAUTHORIZED USE OR SALE, DUPLICATION, OR DISTRIBUTION
// OF THIS PROGRAM OR ANY OF ITS PARTS, IN SOURCE OR BINARY FORMS,
// WITH OR WITHOUT MODIFICATION, WITH THE PURPOSE OF ACQUIRING
// UNLAWFUL MATERIAL OR ANY OTHER BENEFIT IS PROHIBITED!
// THIS PROGRAM IS PROTECTED BY COPYRIGHT LAWS AND YOU MAY NOT
// REVERSE ENGINEER, DECOMPILE, OR DISASSEMBLE IT.

import Foundation
import SwiftUI
import BlinkID

enum UIState {
    case loading
    case home
    case error(String)
    case success(BlinkIDScanningResult)
}

@MainActor
class ViewModel: ObservableObject {
    // Valid: 2027-04-06
    private let licenseKey = "sRwDAAEeY29tLm1pY3JvYmxpbmsuRGlyZWN0QVBJU2FtcGxlAQptaWNyb2JsaW5r7s/u74AMZyT8nEZ+PoxMxbbG8UO1KuzJFS7RGV8U6RnWlhc4uZ+pSIZwqSeioD5cCu8H1wX6PBP6jWebaLBnT8P1ncZOF8rV2ChZHvbhnvlWAZurcwJHrW+U+JEbOB36uFW9KPUvTo8qgMt9urriRMdcUiyB2V2QEHOm"
    private var blinkIDsdk: BlinkIDSdk? = nil
    @Published var state: UIState = .loading
    
    init() {
        Task {
            await initializeSdk()
        }
    }
    
    func initializeSdk() async {
        do {
            let settings = BlinkIDSdkSettings(licenseKey: licenseKey)
            blinkIDsdk = try await BlinkIDSdk.createBlinkIDSdk(withSettings: settings)
        } catch {
            state = .error(error.localizedDescription)
        }
        state = .home
    }
    
    func processImages() async {
        state = .loading
        
        guard let blinkIDsdk = blinkIDsdk
        else {
            state = .error("Failed to perform scan due to missing sdk")
            return
        }
        
        var documentCaptureModule = DocumentCaptureModuleSettings()
        documentCaptureModule.documentImageReturnEnabled = true
        documentCaptureModule.faceImageExtractionEnabled = true
        
        if let session = try? await blinkIDsdk.createScanningSession(sessionSettings: createSettings()) {
            guard let frontUIImage = UIImage(named: "front"),
                  let backUIImage = UIImage(named: "back")
            else { return }
            
            let frontFrameProcessResult = try? await session.process(inputImage: InputImage(uiImage: frontUIImage))
            if let processResult = frontFrameProcessResult?.processResult {
                debugPrint("Processing status Frist: \(processResult)")
            }
            
            
            let backFrameProcessResult = try? await session.process(inputImage: InputImage(uiImage: backUIImage))
            if let processResult = backFrameProcessResult?.processResult {
                debugPrint("Processing status Second: \(processResult)")
            }
            
            let finalResult = await session.getResult()

            debugPrint("final Result: \(finalResult)")
            
            state = .success(finalResult)
        }
        
        
    }
}

func createSettings() -> BlinkIDSessionSettings {
    var documentCapture = DocumentCaptureModuleSettings()
    documentCapture.documentImageReturnEnabled = true
    documentCapture.faceImageExtractionEnabled = true
    
    let scanningSettings = ScanningSettings(
        documentCaptureModule: documentCapture
    )
    
    return BlinkIDSessionSettings(
        inputImageSource:          .photo,
        scanningMode:              .automatic,
        scanningSettings:          scanningSettings
    )
}
