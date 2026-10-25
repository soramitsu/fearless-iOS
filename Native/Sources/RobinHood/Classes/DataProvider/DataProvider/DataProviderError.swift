/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Enum is designed to define possible errors returned
 *  by `DataProvider`.
 */

public enum DataProviderError: Error {
    /// Returned when behavior of the remote source is unexpected
    case unexpectedSourceResult

    /// Returned when behavior of the repository is unexpected
    case unexpectedRepositoryResult

    /// Returned when internal operation unexpectedly cancelled
    case dependencyCancelled

    /// Returned when the existing observer is trying to be added one more time
    case observerAlreadyAdded
}
