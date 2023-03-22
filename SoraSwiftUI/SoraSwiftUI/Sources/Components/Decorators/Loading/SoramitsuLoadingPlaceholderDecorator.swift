import UIKit

public enum SoramitsuLoadingPlaceholderType: CaseIterable {
	case none
	case activity
	case shimmer
	case retry
}

public final class SoramitsuLoadingPlaceholderDecorator {

	/// Тип заглушки
	public var type: SoramitsuLoadingPlaceholderType = .none {
		didSet {
			DispatchQueue.main.async {
				self.updatePlaceholder()
			}
		}
	}

	public private(set) lazy var shimmerview = SoramitsuShimmerView(style: style)

	public private(set) lazy var activityView = SoramitsuActivityIndicatorView(style: style)

	public var retryHandler: (() -> Void)?

	private(set) lazy var retryButton: SoramitsuButton = {
        let button = SoramitsuButton(style: style, size: .large)
		button.sora.stater.animationDuration = 0.4
		let rotation: CGFloat = -1 * .pi
		button.sora.associate(states: .pressed) { sora in
            sora.transform = sora.transform.rotated(by: rotation)
            sora.transform = sora.transform.rotated(by: rotation)
		}
		button.sora.addHandler(for: .touchUpInside) { [weak self] in
			DispatchQueue.main.asyncAfter(deadline: .now() + button.sora.stater.animationDuration) {
				self?.retryHandler?()
			}
		}
		return button
	}()

	weak var view: UIView?

	private let style: SoramitsuStyle

	init(style: SoramitsuStyle) {
		self.style = style
	}

	private func updatePlaceholder() {
		guard let view = view else { return }
		UIView.transition(with: view,
						  duration: CATransaction.animationDuration(),
						  options: [.transitionCrossDissolve, .allowUserInteraction],
						  animations: {
							switch self.type {
							case .none:
								self.stopAll()
							case .activity:
								self.retryButton.removeFromSuperview()
								self.stopShimmer()
								self.add(self.activityView, on: view)
								self.activityView.pinToSuperView(respectingSafeArea: false)
								self.activityView.startAnimating()
							case .shimmer:
								self.retryButton.removeFromSuperview()
								self.stopActivity()
								self.add(self.shimmerview, on: view)
								self.shimmerview.pinToSuperView(respectingSafeArea: false)
								self.shimmerview.sora.startShimmering()
							case .retry:
								self.stopAll()
								view.isUserInteractionEnabled = true
								self.add(self.retryButton, on: view)
								self.retryButton.makeSquare()
								NSLayoutConstraint.activate([
									self.retryButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
									self.retryButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
								])
							}
		})
	}

	private func add(_ subview: UIView, on view: UIView) {
		if let navigationBar = view.subviews.first(where: { $0 is UINavigationBar }) {
			view.insertSubview(subview, belowSubview: navigationBar)
		} else {
			view.addSubview(subview)
		}
	}

	private func stopAll() {
		retryButton.removeFromSuperview()
		stopActivity()
		stopShimmer()
	}

	private func stopActivity() {
		self.activityView.removeFromSuperview()
		self.activityView.stopAnimating()
	}

	private func stopShimmer() {
		self.shimmerview.removeFromSuperview()
		self.shimmerview.sora.stopShimmering()
	}
}
