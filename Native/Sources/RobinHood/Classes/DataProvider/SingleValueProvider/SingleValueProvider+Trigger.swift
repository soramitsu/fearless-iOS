/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

extension SingleValueProvider: DataProviderTriggerDelegate {
    public func didTrigger() {
        dispatchUpdateRepository()
    }
}
