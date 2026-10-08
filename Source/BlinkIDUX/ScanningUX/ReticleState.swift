//  Created by Toni Krešo on 13.11.2024.. 
//  Copyright (c) Microblink. All rights reserved.
//  Modifications are allowed under the terms of the license for files located in the UX/UI lib folder.
//

public enum ReticleState: ReticleStateProtocol {
    case front
    case back
    case barcode
    case barcodeSide
    case mrzSide
    case passportDataPage
    case detecting
    case flip
    case error(String)
    case inactive
    case passport(String)
    case inactiveWithMessage(String)
    
    public static var inactiveState: ReticleState {
        .inactive
    }
    
    public var text: String? {
        switch self {
        case .front:
            return "mb_front_instructions"
        case .back:
            return "mb_back_instructions"
        case .barcode:
            return "mb_barcode_instructions"
        case .barcodeSide:
            return "mb_barcode_id_instructions"
        case .mrzSide:
            return "mb_mrz_id_instructions"
        case .passportDataPage:
            return "mb_passport_scan_data_page_instructions"
        case .flip:
            return "mb_camera_flip_document"
        case .error(let message):
            return message
        case .detecting, .inactive:
            return nil
        case .passport(let message):
            return message
        case .inactiveWithMessage(let message):
            return message
        }
    }
    
    public var duration: Double {
        switch self {
        case .front, .back, .barcode, .barcodeSide, .mrzSide, .passportDataPage:
            2.0
        case .detecting:
            1.5
        case .error(_):
            3.0
        case .flip, .inactive:
            0.0
        case .passport(_), .inactiveWithMessage(_):
            2.0
        }
    }
    
    public var shouldExpire: Bool {
        switch self {
        case .front, .back, .detecting, .inactive, .flip, .barcode, .barcodeSide, .mrzSide, .passportDataPage:
            return false
        case .error(_):
            return true
        case .passport(_), .inactiveWithMessage(_):
            return false
        }
    }
    
    public var canBeFallback: Bool {
        switch self {
        case .front, .back, .barcode, .barcodeSide, .mrzSide, .passportDataPage, .passport(_), .inactiveWithMessage(_):
            return true
        case .flip, .inactive, .error(_), .detecting:
            return false
        }
    }
    
    public var isErrorState: Bool {
        switch self {
        case .error(_):
            return true
        default:
            return false
        }
    }
    
    public var reticleStateAppearance: ReticleStateAppearance {
        switch self {
        case .inactive, .flip, .inactiveWithMessage(_):
            return .empty
        case .error(_):
            return .error
        case .detecting:
            return .detecting
        case .front, .back, .barcode, .barcodeSide, .mrzSide, .passportDataPage, .passport(_):
            return .spinning
        }
    }
}
