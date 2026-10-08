//  Created by Toni Krešo on 13.02.2026..
//  Copyright (c) Microblink. All rights reserved.
//  Modifications are allowed under the terms of the license for files located in the UX/UI lib folder.
//

import SwiftUI

enum FullDocumentOnboardingStep: Int, OnboardingStepProtocol {
    case allFieldsVisible, harshLight, keepStill

    var id: Int { rawValue }

    var image: Image {
        switch self {
        case .allFieldsVisible:
            return Image.allFieldsVisibleImage
        case .harshLight:
            return Image.harshLightImage
        case .keepStill:
            return Image.keepStillImage
        }
    }

    var title: String {
        switch self {
        case .allFieldsVisible:
            return "mb_help_screen_title1"
        case .harshLight:
            return "mb_help_screen_title2"
        case .keepStill:
            return "mb_help_screen_title3"
        }
    }

    var description: String {
        switch self {
        case .allFieldsVisible:
            return "mb_help_screen_msg1"
        case .harshLight:
            return "mb_help_screen_msg2"
        case .keepStill:
            return "mb_help_screen_msg3"
        }
    }
}

enum BarcodeOnlyOnboardingStep: Int, OnboardingStepProtocol {
    case keepBarcodeVisible, harshLight, keepStill

    var id: Int { rawValue }

    var image: Image {
        switch self {
        case .keepBarcodeVisible:
            return Image.keepBarcodeVisibleImage
        case .harshLight:
            return Image.harshLightBarcodeImage
        case .keepStill:
            return Image.keepStillBarcodeImage
        }
    }

    var title: String {
        switch self {
        case .keepBarcodeVisible:
            return "mb_help_screen_barcode_title1"
        case .harshLight:
            return "mb_help_screen_title2"
        case .keepStill:
            return "mb_help_screen_title3"
        }
    }

    var description: String {
        switch self {
        case .keepBarcodeVisible:
            return "mb_help_screen_barcode_msg1"
        case .harshLight:
            return "mb_help_screen_barcode_msg2"
        case .keepStill:
            return "mb_help_screen_barcode_msg3"
        }
    }
}

enum DocumentBarcodeOnboardingStep: Int, OnboardingStepProtocol {
    case keepBarcodeVisible, harshLight, keepStill

    var id: Int { rawValue }

    var image: Image {
        switch self {
        case .keepBarcodeVisible:
            return Image.keepBarcodeVisibleIdImage
        case .harshLight:
            return Image.harshLightImage
        case .keepStill:
            return Image.keepStillImage
        }
    }

    var title: String {
        switch self {
        case .keepBarcodeVisible:
            return "mb_help_screen_barcode_title1"
        case .harshLight:
            return "mb_help_screen_title2"
        case .keepStill:
            return "mb_help_screen_title3"
        }
    }

    var description: String {
        switch self {
        case .keepBarcodeVisible:
            return "mb_help_screen_barcode_msg1"
        case .harshLight:
            return "mb_help_screen_msg2"
        case .keepStill:
            return "mb_help_screen_msg3"
        }
    }
}

enum PassportOnlyOnboardingStep: Int, OnboardingStepProtocol {
    case openPassport, allFieldsVisible, harshLight, keepStill

    var id: Int { rawValue }

    var image: Image {
        switch self {
        case .openPassport:
            return Image.passportHelpShowDataImage
        case .allFieldsVisible:
            return Image.passportAllFieldsVisibleImage
        case .harshLight:
            return Image.passportHarshLightImage
        case .keepStill:
            return Image.passportKeepStillImage
        }
    }

    var title: String {
        switch self {
        case .openPassport:
            return "mb_passport_help_open_passport_title"
        case .allFieldsVisible:
            return "mb_help_screen_title1"
        case .harshLight:
            return "mb_help_screen_title2"
        case .keepStill:
            return "mb_help_screen_title3"
        }
    }

    var description: String {
        switch self {
        case .openPassport:
            return "mb_passport_help_open_passport_subtitle"
        case .allFieldsVisible:
            return "mb_help_screen_msg1"
        case .harshLight:
            return "mb_help_screen_msg2"
        case .keepStill:
            return "mb_help_screen_msg3"
        }
    }
}

enum DocumentMrzOnboardingStep: Int, OnboardingStepProtocol {
    case keepMrzVisible, harshLight, keepStill

    var id: Int { rawValue }

    var image: Image {
        switch self {
        case .keepMrzVisible:
            return Image.keepMrzVisibleImage
        case .harshLight:
            return Image.harshLightImage
        case .keepStill:
            return Image.keepStillImage
        }
    }

    var title: String {
        switch self {
        case .keepMrzVisible:
            return "mb_help_screen_mrz_title1"
        case .harshLight:
            return "mb_help_screen_title2"
        case .keepStill:
            return "mb_help_screen_title3"
        }
    }

    var description: String {
        switch self {
        case .keepMrzVisible:
            return "mb_help_screen_mrz_msg1"
        case .harshLight:
            return "mb_help_screen_msg2"
        case .keepStill:
            return "mb_help_screen_msg3"
        }
    }
}
