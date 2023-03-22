import UIKit

final class SoramitsuBlurDecorator {

	var active: Bool = false {
		didSet {
			updateState()
		}
	}

	weak var view: UIView? {
		didSet {
			updateState()
		}
	}

	private lazy var blurView: UIView = {
		let effect = UIBlurEffect(style: .regular)
		let blur = UIVisualEffectView(effect: effect)
		blur.isUserInteractionEnabled = false
		return blur
	}()

	func viewSizeDidChange() {
		guard let view = self.view else { return }
		blurView.frame = view.bounds
	}

	private func updateState() {
		guard let view = view else { return }
		if active {
			guard !view.subviews.contains(blurView) else { return }
			// Костылек, imageView и titleLabel лэзи, инициализируем их
			if let button = self.view as? UIButton {
				_ = button.imageView
				_ = button.titleLabel
			}
			view.insertSubview(blurView, at: 0)
		} else {
			blurView.removeFromSuperview()
		}
	}
}
