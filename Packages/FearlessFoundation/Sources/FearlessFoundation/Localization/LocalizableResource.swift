import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public struct LocalizableResource<R> {
    private let closure: (Locale) -> R

    public func value(for locale: Locale) -> R {
        return closure(locale)
    }

    public init(closure: @escaping (Locale) -> R) {
        self.closure = closure
    }
}
