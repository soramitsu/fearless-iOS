import UIKit

public final class SoramitsuTapGestureRecognizer: UITapGestureRecognizer {

	public var handler: ((SoramitsuTapGestureRecognizer) -> Void)?

	public init(handler: ((SoramitsuTapGestureRecognizer) -> Void)? = nil) {
		self.handler = handler
		super.init(target: nil, action: nil)
		addTarget(self, action: #selector(gestureDidTap))
	}

	@objc private func gestureDidTap() {
		handler?(self)
	}
}

public extension UIView {

	@discardableResult func addTapGesture(with handler: @escaping (SoramitsuTapGestureRecognizer) -> Void) -> SoramitsuTapGestureRecognizer {
		let gesture = SoramitsuTapGestureRecognizer(handler: handler)
		addGestureRecognizer(gesture)
		return gesture
	}
}
