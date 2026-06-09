import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/


import Foundation

public extension BigNumberAbbreviation {
    static var defaultInitial: BigNumberAbbreviation {
        BigNumberAbbreviation(threshold: 0, divisor: 1.0, suffix: "")
    }

    static var defaultThousands: BigNumberAbbreviation {
        BigNumberAbbreviation(threshold: 1000, divisor: 1000.0, suffix: "K")
    }

    static var defaultMillions: BigNumberAbbreviation {
        BigNumberAbbreviation(threshold: 100_000, divisor: 1_000_000.0, suffix: "M")
    }

    static var defaultBillions: BigNumberAbbreviation {
        BigNumberAbbreviation(threshold: 100_000_000, divisor: 1_000_000_000.0, suffix: "B")
    }
}
