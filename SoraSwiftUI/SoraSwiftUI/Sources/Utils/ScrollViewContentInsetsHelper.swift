import UIKit

public final class ScrollViewContentInsetsHelper: KeyboardEventsListnerHelper {

	public init(scrollView: UIScrollView) {
		let willShowAction: Action = { [weak scrollView] notification in
			if let keyboardRect = notification.keyboardRect(for: UIResponder.keyboardFrameEndUserInfoKey) {
				scrollView?.handleBottomInsetChange(keyboardRect)
			}
		}
		let didHideAction: Action = { [weak scrollView] notification in
			if let keyboardRect = notification.keyboardRect(for: UIResponder.keyboardFrameBeginUserInfoKey) {
				scrollView?.handleBottomInsetChange(keyboardRect)
			}
		}
		super.init(willShowAction: willShowAction, didHideAction: didHideAction)
	}
}

extension UIScrollView {

	func handleBottomInsetChange(_ keyboardFrame: CGRect) {
		let interceptionHeight = frame.height - convert(keyboardFrame, from: nil).minY
		var insets = contentInset
		insets.bottom += interceptionHeight
		UIView.animate(withDuration: CATransaction.animationDuration()) {
			self.contentInset = insets
		}
	}
}

extension Notification {

	func keyboardRect(for key: String) -> CGRect? {
		guard let isLocal = userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? NSNumber, isLocal.boolValue else {
			return nil
		}
		guard let frameValue = userInfo?[key] as? NSValue else {
			return nil
		}
		return frameValue.cgRectValue
	}
}
