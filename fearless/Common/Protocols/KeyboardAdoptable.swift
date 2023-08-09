import UIKit
import SoraFoundation
import SnapKit

protocol KeyboardAdoptable: AnyObject {
    var keyboardHandler: FearlessKeyboardHandler? { get set }

    func updateWhileKeyboardFrameChanging(_ frame: CGRect)
}

extension KeyboardAdoptable {
    func setupKeyboardHandler() {
        guard keyboardHandler == nil else {
            return
        }

        keyboardHandler = FearlessKeyboardHandler(with: nil)
    }

    func clearKeyboardHandler() {
        keyboardHandler = nil
    }
}

protocol KeyboardViewAdoptable: KeyboardAdoptable, KeyboardHandlerDelegate {
    var target: Constraint? { get }

    func offsetFromKeyboardWithInset(_ bottomInset: CGFloat) -> CGFloat
}

private enum KeyboardViewAdoptableConstants {
    static var keyboardHandlerKey: String = "co.jp.fearless.keyboard.handler"
    static var keyboardFrameKey: String = "co.jp.fearless.keyboard.frame"
}

extension KeyboardViewAdoptable where Self: UIViewController {
    var keyboardHandler: FearlessKeyboardHandler? {
        get {
            objc_getAssociatedObject(self, &KeyboardViewAdoptableConstants.keyboardHandlerKey)
                as? FearlessKeyboardHandler
        }

        set {
            objc_setAssociatedObject(
                self,
                &KeyboardViewAdoptableConstants.keyboardHandlerKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN
            )
        }
    }

    func updateWhileKeyboardFrameChanging(_: CGRect) {}

    func setupKeyboardHandler() {
        guard keyboardHandler == nil else {
            return
        }

        let keyboardHandler = FearlessKeyboardHandler(with: self)
        keyboardHandler.handleWillHide = { [weak self] optionalInfo in
            self?.animateFrameChangeIfNeeded(with: optionalInfo, keyboardHidden: true)
        }
        keyboardHandler.handleWillShow = { [weak self] optionalInfo in
            self?.animateFrameChangeIfNeeded(with: optionalInfo, keyboardHidden: false)
        }

        self.keyboardHandler = keyboardHandler
    }

    func apply(keyboardFrame: CGRect, keyboardHidden: Bool) {
        if let target = target {
            apply(keyboardHeight: keyboardHidden ? 0 : keyboardFrame.height, to: target)
            view.layoutIfNeeded()
        }
        let frame = keyboardHidden ? .zero : keyboardFrame
        updateWhileKeyboardFrameChanging(frame)
    }

    private func apply(keyboardHeight: CGFloat, to target: Constraint) {
        target.update(inset: keyboardHeight + offsetFromKeyboardWithInset(keyboardHeight))
    }

    private func animateFrameChangeIfNeeded(with optionalInfo: [AnyHashable: Any]?, keyboardHidden: Bool) {
        guard let info = optionalInfo else {
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

        apply(keyboardFrame: newBounds.cgRectValue, keyboardHidden: keyboardHidden)

        UIView.commitAnimations()
    }
}
