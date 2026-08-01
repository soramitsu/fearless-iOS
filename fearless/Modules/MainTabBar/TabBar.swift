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
        layer.shadowOpacity = 1
        layer.shadowColor = R.color.colorPolkaswapPink()?.cgColor
        layer.shadowRadius = 12
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
        super.init(effect: UIBlurEffect(style: .dark))

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
        let radius = CGFloat(28)

        let cutoutRadius = CGFloat(centerButtonHeight / 2.0) + padding
        let height = bounds.height
        let width = bounds.width
        let halfW = bounds.width / 2.0
        let path = UIBezierPath()
        path.move(to: .zero)

        path.addLine(to: CGPoint(x: halfW - cutoutRadius + padding, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: halfW - cutoutRadius, y: radius / 2.0),
            controlPoint: CGPoint(x: halfW - cutoutRadius, y: 0)
        )
        path.addArc(
            withCenter: CGPoint(x: halfW, y: radius / 2.0),
            radius: cutoutRadius,
            startAngle: .pi,
            endAngle: 0,
            clockwise: false
        )
        path.addQuadCurve(
            to: CGPoint(x: halfW + cutoutRadius - padding, y: 0),
            controlPoint: CGPoint(x: halfW + cutoutRadius, y: 0)
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
