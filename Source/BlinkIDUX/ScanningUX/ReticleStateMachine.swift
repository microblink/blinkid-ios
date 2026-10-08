//  Created by Toni Krešo on 13.02.2026..
//  Copyright (c) Microblink. All rights reserved.
//  Modifications are allowed under the terms of the license for files located in the UX/UI lib folder.
//

import Combine
import Foundation

public class ReticleStateMachine: ReticleStateMachineProtocol {
    public typealias ReticleStateType = ReticleState
    
    @Published public var reticleState: ReticleState
    public var fallbackState: ReticleState
    public var lastReticleStateChange: TimeInterval
    public var eventCounter: [ReticleState : Int]
    public var reticleStateIsInterruptible: Bool
    private var lastPassportErrorOrientation: PassportOrientation?
    
    private let extractionMode: BlinkIDExtractionMode?
    
    public init(extractionMode: BlinkIDExtractionMode?) {
        self.extractionMode = extractionMode
        let initialState = Self.getInitialState(extractionMode: extractionMode)
        self.reticleState = initialState
        self.fallbackState = initialState
        self.lastReticleStateChange = Date().timeIntervalSince1970
        self.eventCounter = [:]
        self.reticleStateIsInterruptible = false
        self.lastPassportErrorOrientation = nil
    }
    
    public func calculateState(using mostFrequentState: ReticleState) -> ReticleState {
        if mostFrequentState == .error("mb_scanning_wrong_page_top") {
            lastPassportErrorOrientation = PassportOrientation.none
        } else if mostFrequentState == .error("mb_scanning_wrong_page_left") {
            lastPassportErrorOrientation = .left90
        } else if mostFrequentState == .error("mb_scanning_wrong_page_right") {
            lastPassportErrorOrientation = .right90
        }

        if case .passport(let message) = mostFrequentState {
            if message == "mb_instructions_scan_barcode_last_page".localizedString {
                return mostFrequentState
            } else {
                if let lastPassportErrorOrientation = lastPassportErrorOrientation {
                    switch lastPassportErrorOrientation {
                    case .none:
                        return ReticleState.passport("mb_top_page_instructions".localizedString)
                    case .left90:
                        return ReticleState.passport("mb_left_page_instructions".localizedString)
                    case .right90:
                        return ReticleState.passport("mb_right_page_instructions".localizedString)
                    }
                }
            }
        }
        return mostFrequentState
    }
    
    public func forcedState(state: ReticleState){
        if case .passport(let message) = state {
            if message == "mb_top_page_instructions" {
                lastPassportErrorOrientation = PassportOrientation.none
            } else if message == "mb_left_page_instructions" {
                lastPassportErrorOrientation = .left90
            } else if message == "mb_right_page_instructions" {
                lastPassportErrorOrientation = .right90
            }
        }
    }
    
    private static func getInitialState(extractionMode: BlinkIDExtractionMode?) -> ReticleState {
        guard let extractionMode = extractionMode else {
            return .front
        }
        
        switch extractionMode {
        case .barcodeOnly:
            return .barcode
        case .documentWithBarcode:
            return .barcodeSide
        case .fullDocument:
            return .front
        case .documentWithMrz:
            return .mrzSide
        case .passportOnly:
            return .passportDataPage
        }
    }
    
    public func setInitialState() {
        reticleState = Self.getInitialState(extractionMode: self.extractionMode)
        reticleStateIsInterruptible = false
        fallbackState = reticleState
        lastReticleStateChange = Date().timeIntervalSince1970
        eventCounter.removeAll()
    }
}
