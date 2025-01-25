//
//  Helper.swift
//  NearbyInteractionSampler
//
//  Created by yuji on 2025/01/25.
//

import Foundation

enum Helper {
    @MainActor static var localFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .medium
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.alwaysShowsDecimalSeparator = true
        formatter.numberFormatter.roundingMode = .ceiling
        formatter.numberFormatter.maximumFractionDigits = 2
        formatter.numberFormatter.minimumFractionDigits = 2
        return formatter
    }()
    
    static var localUnits: UnitLength {
        switch Locale.current.measurementSystem {
        case .metric:
            return .meters
        case .uk, .us:
            return .feet
        default:
            return .meters
        }
    }
}
