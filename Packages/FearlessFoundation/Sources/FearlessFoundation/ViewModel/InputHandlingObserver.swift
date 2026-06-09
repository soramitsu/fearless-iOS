import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/


import Foundation

/**
 *  Interface to be notified when input value changes
 */

public protocol InputHandlingObserver: AnyObject {

    /**
     *  Notifies observer that input value has been changed.
     *
     *  - parameters:
     *      - handler: input handler which manages input value.
     *      - oldValue: old input value which has been changed.
     */

    func didChangeInputValue(_ handler: InputHandling, from oldValue: String)
}

struct InputHandlingObserverWrapper {
    weak private(set) var observer: InputHandlingObserver?

    init(observer: InputHandlingObserver) {
        self.observer = observer
    }
}
