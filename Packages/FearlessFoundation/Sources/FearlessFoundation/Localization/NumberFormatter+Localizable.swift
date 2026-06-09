import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public extension NumberFormatter {
    func localizableResource() -> LocalizableResource<NumberFormatter> {
        return LocalizableResource { locale in
            self.locale = locale
            return self
        }
    }
}
