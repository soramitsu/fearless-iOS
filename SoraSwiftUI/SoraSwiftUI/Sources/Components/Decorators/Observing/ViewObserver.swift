import UIKit

final class ViewObserver: NSObject {

	var viewSizeDidChangeHandler: (() -> Void)?

	private var sizeKeyPaths: [KeyPath<UIView, CGRect>] = [\.frame, \.bounds]
	private var observation: NSKeyValueObservation?

	func observe(_ view: UIView) {
		sizeKeyPaths.forEach {
			observation = view.observe($0, options: .new) { [weak self] _, change in
				if change.oldValue?.size != change.newValue?.size {
					self?.viewSizeDidChangeHandler?()
				}
			}
		}
	}
}
