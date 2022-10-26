import UIKit
import SoraFoundation

public typealias KeyboardFrameChangeHandleBlock = ([AnyHashable: Any]?) -> Void

public class FearlessKeyboardHandler {
    public weak var delegate: KeyboardHandlerDelegate?

    public var handleWillShow: KeyboardFrameChangeHandleBlock?
    public var handleWillHide: KeyboardFrameChangeHandleBlock?

    // MARK: Initialization

    deinit {
        NotificationCenter.default.removeObserver(self)
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

    @objc private func keyboardWillShow(notification: Notification) {
        handleWillShow?(notification.userInfo)
        if let handler = delegate?.keyboardWillShow { handler(notification) }
    }

    @objc private func keyboardDidShow(notification: Notification) {
        if let handler = delegate?.keyboardDidShow { handler(notification) }
    }

    @objc private func keyboardWillHide(notification: Notification) {
        handleWillHide?(notification.userInfo)
        if let handler = delegate?.keyboardWillHide { handler(notification) }
    }

    @objc private func keyboardDidHide(notification: Notification) {
        if let handler = delegate?.keyboardDidHide { handler(notification) }
    }

    @objc private func keyboardWillChangeFrame(notification: Notification) {
        if let handler = delegate?.keyboardWillChangeFrame { handler(notification) }
    }

    @objc private func keyboardDidChangeFrame(notification: Notification) {
        if let handler = delegate?.keyboardDidChangeFrame { handler(notification) }
    }
}
