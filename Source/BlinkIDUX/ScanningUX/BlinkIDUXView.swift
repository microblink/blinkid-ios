//
//  BlinkIDUXView.swift
//  DocumentVerificationUX
//
//  Created by Jura Skrlec on 19.02.2025..
//

import SwiftUI

#if BLINKIDVERIFYUX
import BlinkIDVerify
#elseif BLINKIDUX
import BlinkID
#endif

/// Main scanning view.
/// This view consists of `CameraView` and `Reticle`.
///
/// For `UIEvent` stream, and UX logic, see ``ScanningUXModel``.
private struct BlinkIDUXContentView: View, ScanningUXProtocol, PassportAnimatableView {
    typealias GenericContentView = AnyView
    typealias ScanResult = BlinkIDScanningResult
    typealias AlertType = BlinkIDScanningAlertType
    typealias UXModel = BlinkIDUXModel
    typealias EventType = UIEvent
    typealias ReticleStateMachineType = ReticleStateMachine
    var onboardingSteps: [any OnboardingStepProtocol] {
        switch viewModel.extractionMode {
        case .barcodeOnly:
            return Array(BarcodeOnlyOnboardingStep.allCases)
        case .documentWithBarcode:
            return Array(DocumentBarcodeOnboardingStep.allCases)
        case .documentWithMrz:
            return Array(DocumentMrzOnboardingStep.allCases)
        case .passportOnly:
            return Array(PassportOnlyOnboardingStep.allCases)
        case .fullDocument, nil:
            return Array(FullDocumentOnboardingStep.allCases)
        }
    }

    var onboardingAlert: OnboardingAlertContent {
        switch viewModel.extractionMode {
        case .barcodeOnly:
            return OnboardingAlertContent(
                title: "mb_onboarding_dialog_barcode_title",
                description: "mb_onboarding_dialog_barcode_message",
                image: Image.locateBarcodeImage
            )
        case .documentWithBarcode:
            return OnboardingAlertContent(
                title: "mb_onboarding_dialog_barcode_id_title",
                description: "mb_onboarding_dialog_barcode_id_message",
                image: Image.locateBarcodeIdImage
            )
        case .documentWithMrz:
            return OnboardingAlertContent(
                title: "mb_onboarding_dialog_mrz_id_title",
                description: "mb_onboarding_dialog_mrz_id_message",
                image: Image.locateMrzIdImage
            )
        case .passportOnly:
            return OnboardingAlertContent(
                title: "mb_passport_onboarding_title",
                description: "mb_passport_onboarding_subtitle",
                image: Image.passportOnboardingImage
            )
        case .fullDocument, nil:
            return OnboardingAlertContent(
                title: "mb_onboarding_dialog_title",
                description: "mb_onboarding_dialog_message",
                image: Image.allDetailsVisibleImage
            )
        }
    }

    // Protocol requirement — now @StateObject since the view owns the lifecycle
    @StateObject var viewModel: BlinkIDUXModel

    let theme = BlinkIDTheme.shared
    
    init(
        analyzer: any CameraFrameAnalyzer<CameraFrame, UIEvent>,
        uxSettings: ScanningUXSettings,
        onScanCompleted: @escaping (BlinkIDResultState) -> Void,
        onFrameProcessResult: (@Sendable (FrameProcessResultHandle) async -> Void)?
    ) {
        _viewModel = StateObject(wrappedValue: BlinkIDUXModel(
            analyzer: analyzer,
            uxSettings: uxSettings,
            onScanCompleted: onScanCompleted,
            onFrameProcessResult: onFrameProcessResult
        ))
    }

    public init(viewModel: BlinkIDUXModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        MainView(
            reticleStateMachine: viewModel.reticleStateMachine,
            isTorchOn: $viewModel.isTorchOn,
            showToast: $viewModel.isToastVisible,
            showSheet: $viewModel.showSheet,
            showLicenseErrorAlert: $viewModel.showLicenseErrorAlert,
            flashlightWarningMessage: "mb_flashlight_warning_message".localizedString
        )
    }
}

/// Main scanning view.
/// This view consists of `CameraView` and `Reticle`.
///
/// For `UIEvent` stream, and UX logic, see ``ScanningUXModel``
public struct BlinkIDUXView: View {
    @Environment(\.uxSettings) private var uxSettings
    @Environment(\.frameProcessResultCallback) private var frameProcessResultCallback

    private let analyzer: any CameraFrameAnalyzer<CameraFrame, UIEvent>
    private let onScanCompleted: (BlinkIDResultState) -> Void
    
    // Used only by escape hatch init
    private let externalViewModel: BlinkIDUXModel?

    public init(
        analyzer: any CameraFrameAnalyzer<CameraFrame, UIEvent>,
        onScanCompleted: @escaping (BlinkIDResultState) -> Void
    ) {
        self.analyzer = analyzer
        self.onScanCompleted = onScanCompleted
        self.externalViewModel = nil
    }

    // Escape hatch
    public init(viewModel: BlinkIDUXModel) {
        self.analyzer = viewModel.analyzer // requires analyzer stored on model
        self.onScanCompleted = { _ in }
        self.externalViewModel = viewModel
    }

    public var body: some View {
        if let model = externalViewModel {
            BlinkIDUXContentView(viewModel: model)
        } else {
            BlinkIDUXContentView(
                analyzer: analyzer,
                uxSettings: uxSettings,
                onScanCompleted: onScanCompleted,
                onFrameProcessResult: frameProcessResultCallback
            )
        }
    }
}

// Override the ReticleView implementation in BlinkIDUXView, we have some custom things for BlinkID
extension BlinkIDUXContentView {
    @ViewBuilder
    func ReticleView(reticleStateMachine: ReticleStateMachineType) -> GenericContentView {
        AnyView(
            Group {
                VStack {
                    ZStack {
                        Reticle<ReticleStateMachineType>(diameter: Self.reticleDiameter, reticleStateMachine: reticleStateMachine)
                        if viewModel.showCardImage,
                           let cardImage = viewModel.cardImage {
                            cardImage
                                .resizable()
                                .scaledToFit()
                                .frame(height: 60)
                                .rotation3DEffect(.degrees(viewModel.flipCardDegrees), axis: (x: 0, y: 1, z: 0))
                                .scaleEffect(viewModel.flipCardScale)
                                .accessibilityHidden(true)
                        }
                        if viewModel.showRippleView {
                            Circle()
                                .fill(.white)
                                .frame(height: Self.reticleDiameter)
                                .scaleEffect(viewModel.rippleViewScale)
                                .opacity(viewModel.rippleViewOpacity)
                                .accessibilityHidden(true)
                        }
                        if viewModel.showSuccessImage {
                            viewModel.successImage
                                .resizable()
                                .scaledToFit()
                                .frame(height: Self.reticleDiameter)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.black, .white)
                                .scaleEffect(viewModel.successImageScale)
                                .accessibilityHidden(true)
                        }
                        if viewModel.passportState.showAnimation {
                            if let orientation = viewModel.passportState.orientation {
                                switch orientation {
                                case .none:
                                    PassportAnimationView()
                                case .left90:
                                    PassportAnimationRotatedBy90LeftView()
                                case .right90:
                                    PassportAnimationRotatedBy90RightView()
                                }
                            }
                        }
                    }
                    .frame(height: 100)
                    MessageContainer<ReticleStateMachineType>(theme: self.theme, stateMachine: viewModel.reticleStateMachine)
                }
            }
        )
    }
}
