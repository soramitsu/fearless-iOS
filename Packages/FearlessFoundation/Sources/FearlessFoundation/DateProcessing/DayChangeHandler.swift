import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol DayChangeHandlerDelegate: AnyObject {
    func handlerDidReceiveChange(_ handler: DayChangeHandlerProtocol)
}

public protocol DayChangeHandlerProtocol: AnyObject {
    var delegate: DayChangeHandlerDelegate? { get set }
}

public final class DayChangeHandler: DayChangeHandlerProtocol {
    public weak var delegate: DayChangeHandlerDelegate?

    deinit {
        removeNotificationHandlers()
    }

    public init() {
        setupNotificationHandlers()
    }

    func setupNotificationHandlers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didDayChangeHandler(_:)),
                                               name: .NSCalendarDayChanged,
                                               object: nil)
    }

    func removeNotificationHandlers() {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Private

    @objc func didDayChangeHandler(_ notification: Notification) {
        // notification is dispatched in background thread

        DispatchQueue.main.async {
            self.delegate?.handlerDidReceiveChange(self)
        }
    }
}
