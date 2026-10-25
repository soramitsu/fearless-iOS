/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Protocol is designed to provide an interface for creation
 *  of URLRequest.
 */

public protocol NetworkRequestFactoryProtocol: AnyObject {
    /**
     *  Creates URLRequest.
     *  - returns: URLRequest object.
     */

    func createRequest() throws -> URLRequest
}

/// Closure to create URLRequest
public typealias NetworkRequestCreationBlock = () throws -> URLRequest

/**
 *  Implementation of the ```NetworkRequestFactoryProtocol``` designed
 *  to wrap url request creation closure.
 */

public final class BlockNetworkRequestFactory: NetworkRequestFactoryProtocol {
    private var requestBlock: NetworkRequestCreationBlock

    /**
     *  Creates factory with closure.
     *
     *  - parameters:
     *    - requestClosure: Closure to create URLRequest.
     */

    public init(requestBlock: @escaping NetworkRequestCreationBlock) {
        self.requestBlock = requestBlock
    }

    public func createRequest() throws -> URLRequest {
        try requestBlock()
    }
}
