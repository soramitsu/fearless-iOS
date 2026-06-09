import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/


import Foundation

public enum TokenSymbolPosition {
    case prefix
    case suffix
}

open class TokenFormatter: LocalizableDecimalFormatting {
    let decimalFormatter: LocalizableDecimalFormatting
    let tokenSymbol: String
    let separator: String
    let position: TokenSymbolPosition

    open var locale: Locale! {
        get {
            decimalFormatter.locale
        }

        set {
            decimalFormatter.locale = newValue
        }
    }

    public init(decimalFormatter: LocalizableDecimalFormatting,
                tokenSymbol: String,
                separator: String = "",
                position: TokenSymbolPosition = .prefix) {
        self.decimalFormatter = decimalFormatter
        self.tokenSymbol = tokenSymbol
        self.separator = separator
        self.position = position
    }

    open func stringFromDecimal(_ value: Decimal) -> String? {
        guard let formattedAmount = decimalFormatter.stringFromDecimal(value) else {
            return nil
        }

        switch position {
        case .prefix:
            return "\(tokenSymbol)\(separator)\(formattedAmount)"
        case .suffix:
            return "\(formattedAmount)\(separator)\(tokenSymbol)"
        }
    }
}
