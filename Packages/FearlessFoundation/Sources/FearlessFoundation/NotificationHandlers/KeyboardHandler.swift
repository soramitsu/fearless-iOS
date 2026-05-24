/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

@objc public protocol KeyboardHandlerDelegate {
    @objc optional func keyboardWillShow(notification: Notification)
    @objc optional func keyboardDidShow(notification: Notification)
    @objc optional func keyboardWillHide(notification: Notification)
    @objc optional func keyboardDidHide(notification: Notification)
    @objc optional func keyboardWillChangeFrame(notification: Notification)
    @objc optional func keyboardDidChangeFrame(notification: Notification)
}

public typealias KeyboardFrameChangeAnimationBlock = (CGRect) -> Void

public class KeyboardHandler {
    public weak var delegate: KeyboardHandlerDelegate?

    public var animateOnFrameChange: KeyboardFrameChangeAnimationBlock?

    // MARK: Initialization

    deinit {
        removeNotificationsObserver()
    }

    public convenience init() { self.init(with: nil) }

    public init(with delegate: KeyboardHandlerDelegate?) {
        self.delegate = delegate

        setupNotificationsObserver()
    }

    // MARK: Observation

    private func setupNotificationsObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(notification:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidShow(notification:)),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(notification:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidHide(notification:)),
            name: UIResponder.keyboardDidHideNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(notification:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidChangeFrame(notification:)),
            name: UIResponder.keyboardDidChangeFrameNotification,
            object: nil
        )
    }

    @objc private func removeNotificationsObserver() {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func keyboardWillShow(notification: Notification) {
        if let handler = delegate?.keyboardWillShow { handler(notification) }
    }

    @objc private func keyboardDidShow(notification: Notification) {
        if let handler = delegate?.keyboardDidShow { handler(notification) }
    }

    @objc private func keyboardWillHide(notification: Notification) {
        if let handler = delegate?.keyboardWillHide { handler(notification) }
    }

    @objc private func keyboardDidHide(notification: Notification) {
        if let handler = delegate?.keyboardDidHide { handler(notification) }
    }

    @objc private func keyboardWillChangeFrame(notification: Notification) {
        animateFrameChangeIfNeeded(with: notification.userInfo)

        if let handler = delegate?.keyboardWillChangeFrame { handler(notification) }
    }

    @objc private func keyboardDidChangeFrame(notification: Notification) {
        if let handler = delegate?.keyboardDidChangeFrame { handler(notification)}
    }

    private func animateFrameChangeIfNeeded(with optionalInfo: [AnyHashable: Any]?) {
        guard let info = optionalInfo, let animationBlock = animateOnFrameChange else {
            return
        }

        guard let newBounds = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return
        }

        let duration: TimeInterval = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval) ?? 0.0
        let curveRawValue: Int = (info[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int) ?? 0
        let curve = UIView.AnimationCurve(rawValue: curveRawValue) ?? UIView.AnimationCurve.linear

        UIView.beginAnimations(nil, context: nil)
        UIView.setAnimationDuration(duration)
        UIView.setAnimationCurve(curve)

        animationBlock(newBounds.cgRectValue)

        UIView.commitAnimations()
    }
}
