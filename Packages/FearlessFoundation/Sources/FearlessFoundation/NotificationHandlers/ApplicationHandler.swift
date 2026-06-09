/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

@objc public protocol ApplicationHandlerDelegate {
    @objc optional func didReceiveWillResignActive(notification: Notification)
    @objc optional func didReceiveDidBecomeActive(notification: Notification)
    @objc optional func didReceiveWillEnterForeground(notification: Notification)
    @objc optional func didReceiveDidEnterBackground(notification: Notification)
}

public protocol ApplicationHandlerProtocol: AnyObject {
    var delegate: ApplicationHandlerDelegate? { get set }
}

public class ApplicationHandler: NSObject, ApplicationHandlerProtocol {

    public weak var delegate: ApplicationHandlerDelegate?

    deinit {
        removeNotificationHandlers()
    }

    public init(with delegate: ApplicationHandlerDelegate? = nil) {
        super.init()

        self.delegate = delegate

        setupNotificationHandlers()
    }

    // MARK: Observation

    private func setupNotificationHandlers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(willResignActiveHandler(notification:)),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didBecomeActiveHandler(notification:)),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(willEnterForeground(notification:)),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didEnterBackground(notification:)),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
    }

    private func removeNotificationHandlers() {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Handlers

    @objc func willResignActiveHandler(notification: Notification) {
        delegate?.didReceiveWillResignActive?(notification: notification)
    }

    @objc func didBecomeActiveHandler(notification: Notification) {
        delegate?.didReceiveDidBecomeActive?(notification: notification)
    }

    @objc func willEnterForeground(notification: Notification) {
        delegate?.didReceiveWillEnterForeground?(notification: notification)
    }

    @objc func didEnterBackground(notification: Notification) {
        delegate?.didReceiveDidEnterBackground?(notification: notification)
    }
}
