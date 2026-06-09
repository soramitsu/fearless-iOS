import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

open class BigNumberFormatter: LocalizableDecimalFormatting {
    private let formatter: LocalizableDecimalFormatting
    private let abbreviations: [BigNumberAbbreviation]

    public convenience init(
        abbreviations: [BigNumberAbbreviation],
        precision: Int = 1,
        rounding: NumberFormatter.RoundingMode = .halfUp,
        usesIntGrouping: Bool = false
    ) {
        let numberFormatter = NumberFormatter.decimalFormatter(
            precision: precision,
            rounding: rounding,
            usesIntGrouping: usesIntGrouping
        )

        self.init(abbreviations: abbreviations, formatter: numberFormatter)
    }

    public init(abbreviations: [BigNumberAbbreviation], formatter: LocalizableDecimalFormatting) {
        self.abbreviations = abbreviations.sorted { abb1, abb2 in abb1.threshold < abb2.threshold }
        self.formatter = formatter
    }

    open var locale: Locale! = Locale.current

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open func stringFromDecimal(_ value: Decimal) -> String? {
        guard value >= 0, !abbreviations.isEmpty else {
            return nil
        }

        var index = abbreviations.firstIndex { value < $0.threshold } ?? abbreviations.count
        index = max(0, index - 1)

        let abbreviation = abbreviations[index]

        let result = value / abbreviation.divisor

        let localFormatter = abbreviation.formatter ?? formatter
        localFormatter.locale = locale

        guard let string = localFormatter.stringFromDecimal(result) else {
            return nil
        }

        return string + abbreviation.suffix
    }
}
