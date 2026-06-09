import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/


import Foundation

open class DynamicPrecisionFormatter: LocalizableDecimalFormatting {
    // max mantissa length in digits of Decimal
    static let maxPrecision: UInt8 = 38

    let numberFormatter: NumberFormatter
    let preferredPrecision: UInt8

    public init(
        preferredPrecision: UInt8,
        roundingMode: NumberFormatter.RoundingMode = .halfUp,
        usesIntGrouping: Bool = false
    ) {
        self.preferredPrecision = min(preferredPrecision, Self.maxPrecision)

        numberFormatter = NumberFormatter.decimalFormatter(
            precision: 0,
            rounding: roundingMode,
            usesIntGrouping: usesIntGrouping
        )
    }

    open var locale: Locale! {
        get {
            numberFormatter.locale
        }

        set {
            numberFormatter.locale = newValue
        }
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open func stringFromDecimal(_ value: Decimal) -> String? {
        let maybePrecision = (preferredPrecision..<Self.maxPrecision).first { prec in
            let precValue = (value as NSDecimalNumber).multiplying(byPowerOf10: Int16(prec)) as Decimal
            return precValue >= 1.0
        }

        let precision = max(maybePrecision ?? preferredPrecision, preferredPrecision)

        numberFormatter.maximumFractionDigits = Int(precision)

        return numberFormatter.string(from: value as NSNumber)
    }
}
