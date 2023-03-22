import UIKit

public final class SoramitsuPanGestureRecognizer: UIPanGestureRecognizer {

	public var handler: ((SoramitsuPanGestureRecognizer) -> Void)?

	public init(handler: ((SoramitsuPanGestureRecognizer) -> Void)? = nil) {
		self.handler = handler
		super.init(target: nil, action: nil)
		addTarget(self, action: #selector(gestureDidTap))
	}

	@objc private func gestureDidTap() {
		handler?(self)
	}
}

public extension UIView {

	@discardableResult func addPanGesture(with handler: @escaping (SoramitsuPanGestureRecognizer) -> Void) -> SoramitsuPanGestureRecognizer {
		let gesture = SoramitsuPanGestureRecognizer(handler: handler)
		addGestureRecognizer(gesture)
		return gesture
	}
}
