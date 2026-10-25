/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

extension DataProvider: DataProviderTriggerDelegate {
    public func didTrigger() {
        dispatchUpdateRepository()
    }
}
