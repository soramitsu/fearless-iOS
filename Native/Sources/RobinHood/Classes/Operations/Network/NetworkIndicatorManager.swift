/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import UIKit

/**
 *  Protocol is designed to manage display of the network activity indicator.
 *
 *  Network indicator is displayed if number of increments greater than number of decrements.
 */

public protocol NetworkIndicatorManagerProtocol {
    /// Display network activity indicator.
    func increment()

    /// Hide network actity indicator if there is no running network operations.
    func decrement()
}

/**
 *  Class is designed to provide implementation of ```NetworkIndicatorManagerProtocol```.
 */

public final class NetworkIndicatorManager {
    static let shared = NetworkIndicatorManager()

    let managerQueue = DispatchQueue(label: UUID().uuidString)

    var numberOfOperations = 0

    private init() {}
}

extension NetworkIndicatorManager: NetworkIndicatorManagerProtocol {
    public func increment() {
        managerQueue.async {
            self.numberOfOperations += 1

            if self.numberOfOperations == 1 {
                DispatchQueue.main.async {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = true
                }
            }
        }
    }

    public func decrement() {
        managerQueue.async {
            guard self.numberOfOperations > 0 else {
                return
            }

            self.numberOfOperations -= 1

            if self.numberOfOperations == 0 {
                DispatchQueue.main.async {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                }
            }
        }
    }
}
