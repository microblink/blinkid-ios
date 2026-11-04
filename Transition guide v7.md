# Transition Guide: BlinkID v6 to BlinkID v7 SDK

This guide will help you migrate your application from BlinkID v6 to the new BlinkID v7 SDK. The BlinkID v7 SDK provides a modernized approach to document scanning with improved architecture and SwiftUI support.

## Key Differences

### 1. Architecture Changes

- **New Core Components**: Instead of MBRecognizer-based architecture, BlinkID uses a streamlined Session-based approach
- **Modern Swift Features**: Built with Swift 6, leveraging latest concurrency features
- **SwiftUI First**: Native SwiftUI support through BlinkIDUX package
- **Simplified Flow**: More straightforward API with clearer separation of concerns

### 2. Integration Methods

#### BlinkID (v6):
```swift
// Multiple integration methods
- CocoaPods
- Carthage
- Swift Package Manager
- Manual Integration
```

#### BlinkID (v7):
```swift
// Two primary methods
1. Swift Package Manager (Recommended)
2. Manual Integration
```

## Migration Guide

### 1. Update Dependencies

#### Remove Old Dependencies:
```ruby
# Remove from Podfile if using CocoaPods
pod 'PPBlinkID'

# Remove from Cartfile if using Carthage
binary "https://github.com/microblink/blinkid-ios/blob/master/blinkid-ios.json"
```

#### Add New Dependencies:

```swift
// Add to Swift Package Manager
dependencies: [
    .package(url: "https://github.com/microblink/blinkid-ios.git", 
             .upToNextMajor(from: "7.0.0"))
]
```

### 2. Update Import Statements

#### Old:
```swift
import BlinkID
```

#### New:
```swift
import BlinkID
import BlinkIDUX  // If using the UX components
```

### 3. Initialization Changes

#### Old (BlinkID v6):
```swift
// Old initialization
MBMicroblinkSDK.shared().setLicenseKey("license-key")

// Creating recognizer
let blinkIdMultiSideRecognizer = MBBlinkIdMultiSideRecognizer()
let recognizerCollection = MBRecognizerCollection(recognizers: [blinkIdMultiSideRecognizer])
```

#### New (BlinkID v7):
```swift
// New initialization
let settings = BlinkIDSdkSettings(
    licenseKey: "your-license-key",
    downloadResources: true
)

let sdk = try await BlinkIDSdk.createBlinkIDSdk(withSettings: settings)
let session = await sdk.createScanningSession()
```

### 4. UI Implementation Changes

#### Old (BlinkID v6):

```swift
// Using BlinkID overlay controller
let settings = MBBlinkIdOverlaySettings()
let blinkIdOverlayViewController = MBBlinkIdOverlayViewController(
    settings: settings,
    recognizerCollection: recognizerCollection,
    delegate: self
)

let recognizerRunnerViewController = MBViewControllerFactory.recognizerRunnerViewController(
    withOverlayViewController: blinkIdOverlayViewController
)
```

#### New (BlinkID v7):

```swift
// Using BlinkIDUX
let analyzer = await BlinkIDAnalyzer(
    sdk: sdk,
    eventStream: BlinkIDEventStream()
)

let viewModel = ScanningUXModel(analyzer: analyzer)

// In SwiftUI
struct ContentView: View {
    var body: some View {
        BlinkIDUXView(viewModel: viewModel)
    }
}
```

### 5. Result Handling

#### Old (BlinkID v6):
```swift
// BlinkID delegate method
func blinkIdOverlayViewControllerDidFinishScanning( _ blinkIdOverlayViewController: MBBlinkIdOverlayViewController, state: MBRecognizerResultState) {
    if state == .valid {
        // Access results through recognizer
        let result = blinkIdMultiSideRecognizer.result
    }
}
```

#### New (BlinkID v7):

```swift
// Process results
let frameProcessResult = await session.process(inputImage: capturedImage)
if if frameProcessResult.processResult?.scanningResultCompleteness.scanningStatus == .documentScanned {
    let finalResult = await session.getResult()
    // Handle the result
}

// Or using SwiftUI binding
viewModel.$scanningResult
    .sink { scanningResult in
        if let result = scanningResult {
            // Handle the result
        }
    }
    .store(in: &cancellables)
```

### 6. Custom UI Implementation

#### Old (BlinkID v6):
```swift
class CustomOverlayViewController: MBCustomOverlayViewController {
    // Custom overlay implementation
}
```

#### New (BlinkID v7):

```swift
// Create custom ViewModel
class CustomViewModel: ObservableObject {
    let camera: Camera = Camera()
    let analyzer: any CameraFrameAnalyzer<BlinkIDScanninResult, UIEvent>
    
    @Published var captureResult: BlinkIDScanningResultState?
    
    init(analyzer: any CameraFrameAnalyzer<BlinkIDScanninResult, UIEvent>) {
        self.analyzer = analyzer
    }
}

// Create custom SwiftUI View
struct CustomScanView: View {
    @StateObject var viewModel: CustomViewModel
    
    var body: some View {
        CameraView(camera: viewModel.camera)
            .task {
                await viewModel.camera.start()
                await viewModel.analyze()
            }
    }
}
```

## Additional Considerations

### Resource Management

- BlinkID SDK supports both downloaded and bundled resources
- Configure resource handling through `BlinkIDSdkSettings`:
  ```swift
  let settings = BlinkIDSdkSettings(
      licenseKey: "your-license-key",
      downloadResources: true,  // Set to false for bundled resources
      resourceLocalFolder: "CustomFolder"  // Optional custom storage location
  )
  ```

## Best Practices for Migration

1. **Gradual Migration**:
   - Consider migrating feature by feature if possible
   - Test thoroughly in a development environment before production deployment

2. **Resource Management**:
   - Decide between downloaded or bundled resources early in the migration
   - Set up proper resource paths and verify resource loading

3. **UI/UX Considerations**:
   - Take advantage of SwiftUI if possible
   - Consider reimplementing custom UI components using the new architecture

4. **Error Handling**:
   - Update error handling to work with the new async/await pattern
   - Implement proper error handling for resource downloading if used

## Support and Resources

- For API documentation: Visit the [BlinkIDVerify](http://microblink.github.io/blinkid-swift-package/docs/blinkid/) and [BlinkIDVerifyUX](http://microblink.github.io/blinkid-ios/docs/blinkidux/) documentation
- For support: Contact technical support through the support portal
