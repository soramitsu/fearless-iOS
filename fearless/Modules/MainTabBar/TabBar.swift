import Foundation
import UIKit

final class TabBarMiddleButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)

        let image = R.image.polkaswapPinkButton()?
            .withRenderingMode(.alwaysTemplate)
            .tinted(with: R.color.colorPolkaswapPink()!)
        setImage(image, for: .normal)
        backgroundColor = R.color.colorWhite()
        accessibilityLabel = "Polkaswap"
        accessibilityTraits = .button
        layer.shadowOpacity = 1
        layer.shadowColor = R.color.colorPolkaswapPink()?.cgColor
        layer.shadowRadius = 12
    }

    override var isSelected: Bool {
        didSet {
            layer.shadowOpacity = isSelected ? 1 : 0.45
            transform = isSelected ? CGAffineTransform(scaleX: 1.05, y: 1.05) : .identity
            accessibilityTraits = isSelected ? [.button, .selected] : .button
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        rounded()
    }
}

final class TabBarBackgroundView: UIVisualEffectView {
    init() {
        super.init(effect: nil)

        contentView.backgroundColor = R.color.colorBlack19()
        clipsToBounds = true
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.mask = createMaskLayer()
    }

    private func createMaskLayer() -> CAShapeLayer {
        let padding: CGFloat = 6.0
        let centerButtonHeight: CGFloat = 56.0

        let cutoutRadius = CGFloat(centerButtonHeight / 2.0) + padding
        let height = bounds.height
        let width = bounds.width
        let halfW = bounds.width / 2.0
        let path = UIBezierPath()
        path.move(to: .zero)

        path.addLine(to: CGPoint(x: halfW - cutoutRadius, y: 0))
        path.addArc(
            withCenter: CGPoint(x: halfW, y: 0),
            radius: cutoutRadius,
            startAngle: .pi,
            endAngle: 0,
            clockwise: false
        )

        path.addLine(to: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0.0, y: height))
        path.close()

        let maskLayer = CAShapeLayer()
        maskLayer.strokeColor = UIColor.clear.cgColor
        maskLayer.fillColor = UIColor.white.cgColor
        maskLayer.lineWidth = 0
        maskLayer.path = path.cgPath
        maskLayer.fillRule = .evenOdd

        return maskLayer
    }
}

/// A single accessible action for each surrounding tab avoids announcing the
/// system center item a second time beside the raised Polkaswap button.
final class TabBarAccessibilityElement: UIAccessibilityElement {
    private let activate: () -> Void

    init(container: Any, activate: @escaping () -> Void) {
        self.activate = activate
        super.init(accessibilityContainer: container)
    }

    override func accessibilityActivate() -> Bool {
        activate()
        return true
    }
}
