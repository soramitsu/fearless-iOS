/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/**
 *  Protocol is designed to provide an interface of modifying
 *  network request of an operation before sending it.
 *
 *  Implementation should provide a convienent way of request
 *  modification for use cases when there is a need to modify
 *  different requests in a common way.
 */

public protocol NetworkRequestModifierProtocol {
    /**
     *  Modifies URLRequest.
     *
     *  - parameters:
     *    - request: URLRequest to modify.
     *  - returns: Modified URLRequest.
     */
    func modify(request: URLRequest) throws -> URLRequest
}
