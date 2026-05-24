import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public extension DateFormatter {
    func localizableResource() -> LocalizableResource<DateFormatter> {
        return LocalizableResource { locale in
            self.locale = locale
            return self
        }
    }
}
