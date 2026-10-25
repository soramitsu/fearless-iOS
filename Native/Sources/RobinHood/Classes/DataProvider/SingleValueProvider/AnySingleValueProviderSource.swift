/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Type erasure implementation of `SingleValueProviderSourceProtocol` protocol. It should be used
 *  to wrap concrete implementation of `SingleValueProviderSourceProtocol` before passing as dependency,
 *  for example, to single value provider.
 */

public final class AnySingleValueProviderSource<T>: SingleValueProviderSourceProtocol {
    public typealias Model = T

    private let _fetch: () -> CompoundOperationWrapper<Model?>

    /**
     *  Initializes type erasure object with implementation of single value provider source protocol.
     *
     *  - parameters:
     *    - source: Implementation of `SingleValueProviderSourceProtocol`.
     */

    public init<U: SingleValueProviderSourceProtocol>(_ source: U) where U.Model == Model {
        _fetch = source.fetchOperation
    }

    public init(fetch: @escaping () -> CompoundOperationWrapper<Model?>) {
        _fetch = fetch
    }

    public func fetchOperation() -> CompoundOperationWrapper<Model?> {
        _fetch()
    }
}
