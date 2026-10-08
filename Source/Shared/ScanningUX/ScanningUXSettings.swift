//  Created by Toni Krešo on 17.09.2025..
//  Copyright (c) Microblink. All rights reserved.
//  Modifications are allowed under the terms of the license for files located in the UX/UI lib folder.
//

import Foundation

public struct ScanningUXSettings {
    /// Determines if alert will be shown when scanning start.
    let showIntroductionAlert: Bool
    
    /// Determines if help button for raising an onboarding sheet will be shown.
    let showHelpButton: Bool
    
    /// The preferred camera position to use when capturing document.
    /// This value represents the user’s choice of front or back camera.
    /// The system determines the actual physical camera device.
    let preferredCameraPosition: Camera.CameraPosition
    
    /// Determines whether haptic feedback is played for scanning-related events.
    ///
    /// When enabled, haptic responses are generated during scanning activities,
    /// such as detection updates or user interactions (e.g., toggling the flashlight).
    /// When disabled, no haptic feedback is produced.
    let allowHapticFeedback: Bool
    
    /// Determines whether sound is played for scanning-success events.
    ///
    /// When enabled, scan sounds are generated during scanning-success events,
    /// such as side scanned.
    /// When disabled, no sound is produced.
    let allowScanSound: Bool
    
    /// Duration in seconds before the help tooltip is shown.
    /// If less than or equal to zero, tooltip won't be auto shown.
    /// Defaults to 10.0
    public var helpTooltipShowDelay: TimeInterval
    
    /// Duration in seconds before the help tooltip is hidden.
    /// If less than or equal to zero, tooltip won't be auto hidden.
    /// Defaults to 5.0
    public var helpTooltipHideDelay: TimeInterval
    
    public init(showIntroductionAlert: Bool = true,
                showHelpButton: Bool = true,
                preferredCameraPosition: Camera.CameraPosition = .back,
                allowHapticFeedback: Bool = true,
                allowScanSound: Bool = true,
                helpTooltipShowDelay: TimeInterval = 10.0,
                helpTooltipHideDelay: TimeInterval = 5.0) {
        self.showIntroductionAlert = showIntroductionAlert
        self.showHelpButton = showHelpButton
        self.preferredCameraPosition = preferredCameraPosition
        self.allowHapticFeedback = allowHapticFeedback
        self.allowScanSound = allowScanSound
        self.helpTooltipShowDelay = helpTooltipShowDelay
        self.helpTooltipHideDelay = helpTooltipHideDelay
    }
}
