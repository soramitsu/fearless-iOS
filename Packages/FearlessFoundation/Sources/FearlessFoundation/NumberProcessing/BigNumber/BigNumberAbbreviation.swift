import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public struct BigNumberAbbreviation {
    public let threshold: Decimal
    public let divisor: Decimal
    public let suffix: String
    public let formatter: LocalizableDecimalFormatting?

    public init(
        threshold: Decimal,
        divisor: Decimal,
        suffix: String,
        formatter: LocalizableDecimalFormatting? = nil
    ) {
        self.threshold = threshold
        self.divisor = divisor
        self.suffix = suffix
        self.formatter = formatter
    }
}
