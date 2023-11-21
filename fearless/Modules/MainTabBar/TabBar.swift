import Foundation
import UIKit

final class TabBar: UITabBar {
    public var middleButton: UIButton = {
        let middleButton = UIButton()
        let image = R.image.polkaswapPinkButton()?.withRenderingMode(.alwaysTemplate).tinted(with: R.color.colorPolkaswapPink()!)
        middleButton.setImage(image, for: .normal)
        middleButton.backgroundColor = R.color.colorWhite()
        middleButton.layer.shadowOpacity = 1
        middleButton.layer.shadowColor = R.color.colorPolkaswapPink()?.cgColor
        middleButton.layer.shadowRadius = 12
        return middleButton
    }()

    private lazy var bluredView: UIView = {
        let blurEffect = UIBlurEffect(style: .dark)
        let bluredView = UIVisualEffectView(effect: blurEffect)
        bluredView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        bluredView.layer.mask = createMaskLayer()
        bluredView.clipsToBounds = true
        return bluredView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        bluredView.frame = bounds
        bluredView.layer.mask = createMaskLayer()
        middleButton.rounded()
    }

    override public func draw(_ rect: CGRect) {
        super.draw(rect)
    }

    private func setupLayout() {
        backgroundColor = .clear
        addSubview(bluredView)
        addSubview(middleButton)

        middleButton.snp.makeConstraints { make in
            make.size.equalTo(56)
            make.centerX.equalToSuperview()
            make.centerY.equalTo(bluredView.snp.top).offset(14)
        }
    }

    private func createMaskLayer() -> CAShapeLayer {
        let padding: CGFloat = 6.0
        let centerButtonHeight: CGFloat = 56.0
        let r = CGFloat(28)

        let f = CGFloat(centerButtonHeight / 2.0) + padding
        let h = frame.height
        let w = frame.width
        let halfW = frame.width / 2.0
        let path = UIBezierPath()
        path.move(to: .zero)

        path.addLine(to: CGPoint(x: halfW - f + padding, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: halfW - f, y: r / 2.0),
            controlPoint: CGPoint(x: halfW - f, y: 0)
        )
        path.addArc(
            withCenter: CGPoint(x: halfW, y: r / 2.0),
            radius: f,
            startAngle: .pi,
            endAngle: 0,
            clockwise: false
        )
        path.addQuadCurve(
            to: CGPoint(x: halfW + f - padding, y: 0),
            controlPoint: CGPoint(x: halfW + f, y: 0)
        )

        path.addLine(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0.0, y: h))
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
