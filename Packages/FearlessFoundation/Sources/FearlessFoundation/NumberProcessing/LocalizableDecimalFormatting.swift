import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/


import Foundation

public protocol LocalizableDecimalFormatting: AnyObject {
    var locale: Locale! { get set }

    func stringFromDecimal(_ value: Decimal) -> String?
}

extension NumberFormatter: LocalizableDecimalFormatting {
    public static func decimalFormatter(
        precision: Int,
        rounding: NumberFormatter.RoundingMode,
        usesIntGrouping: Bool = false
    ) -> NumberFormatter {

        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumIntegerDigits = 1
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = precision
        numberFormatter.roundingMode = rounding
        numberFormatter.usesGroupingSeparator = usesIntGrouping
        numberFormatter.alwaysShowsDecimalSeparator = false

        return numberFormatter
    }

    public func stringFromDecimal(_ value: Decimal) -> String? {
        string(from: value as NSNumber)
    }
}
