import UIKit

public final class SoramitsuShimmerView: UIView, Molecule {

	private struct Constants {
		static let animationKey = "shimmerAnimation"
	}

	public let sora: SoramitsuShimmerViewConfiguration<SoramitsuShimmerView>

	private let gradientLayer: CAGradientLayer = {
		let layer = CAGradientLayer()
		layer.locations = [0, 0.5, 1].map({ NSNumber(value: $0) })
		return layer
	}()

	private lazy var animation: CABasicAnimation = {
		let animation = CABasicAnimation(keyPath: "locations")
		animation.repeatCount = .infinity
		animation.duration = 0.9
		animation.isRemovedOnCompletion = false
		configure(animation: animation)
		return animation
	}()

	init(style: SoramitsuStyle) {
        sora = SoramitsuShimmerViewConfiguration(style: style)
		super.init(frame: .zero)
        sora.backgroundColor = .bgSurfaceVariant
        sora.owner = self
		setupViews()
	}

	required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

	public override func layoutSubviews() {
		super.layoutSubviews()
		gradientLayer.frame = bounds
	}

	func updateColors() {
		let firstColor = sora.style.palette.color(sora.mainShimmerColor).cgColor
		let secondColor = sora.style.palette.color(sora.secondShimmerColor).cgColor
		gradientLayer.colors = [firstColor, secondColor, firstColor]
	}

	func updateDirections() {
		switch sora.position {
		case .diagonally:
			gradientLayer.startPoint = .zero
			gradientLayer.endPoint = CGPoint(x: 1, y: 1)
		case .vertical:
			gradientLayer.startPoint = .zero
			gradientLayer.endPoint = CGPoint(x: 0, y: 1)
		case .horizontal:
			gradientLayer.startPoint = .zero
			gradientLayer.endPoint = CGPoint(x: 1, y: 0)
		}
		configure(animation: animation)
	}

	func startAnimation() {
		gradientLayer.add(animation, forKey: Constants.animationKey)
	}

	func stopAnimation() {
		gradientLayer.removeAnimation(forKey: Constants.animationKey)
	}

	private func setupViews() {
		layer.addSublayer(gradientLayer)
		startAnimation()
	}

	private func configure(animation: CABasicAnimation) {
		let firstValue = [-1.0, -0.5, 0.0]
		let secondValue = [1.0, 1.5, 2.0]
		let isReversed = sora.direction == .reverse

		animation.fromValue = isReversed ? secondValue : firstValue
		animation.toValue =	isReversed ? firstValue : secondValue
	}
}

public extension SoramitsuShimmerView {
	convenience init() {
		self.init(style: SoramitsuUI.shared.style)
	}
}
