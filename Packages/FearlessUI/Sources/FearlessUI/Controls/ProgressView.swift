/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

@IBDesignable
open class ProgressView: UIView {
    private var progressLayer: CAShapeLayer!

    @IBInspectable
    open var fillColor: UIColor = .black {
        didSet {
            setNeedsDisplay()
        }
    }

    @IBInspectable
    open var progressColor: UIColor = .white {
        didSet {
            applyProgressColor()
        }
    }

    @IBInspectable
    open private(set) var progress: CGFloat = 0.0 {
        didSet {
            applyPath()
        }
    }

    @IBInspectable
    open var cornerRadius: CGFloat = 0.0 {
        didSet {
            applyPath()
            setNeedsDisplay()
        }
    }

    // MARK: Animation

    public var animationDuration: CGFloat = 0.6
    public var animationTimingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)

    open func setProgress(_ progress: CGFloat, animated: Bool) {
        let normalizedProgress: CGFloat = min(1.0, max(0, progress))

        guard animated else {
            self.progress = normalizedProgress
            return
        }

        let animation = CABasicAnimation(keyPath: "path")
        animation.duration = CFTimeInterval(animationDuration * abs(self.progress - normalizedProgress))
        animation.fromValue = createShapePathFor(progress: self.progress).cgPath
        animation.toValue = createShapePathFor(progress: normalizedProgress).cgPath
        animation.isRemovedOnCompletion = false
        animation.timingFunction = animationTimingFunction
        progressLayer.add(animation, forKey: animation.keyPath)

        self.progress = normalizedProgress
    }

    // MARK: Initialize

    override public init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    open func configure() {
        backgroundColor = .clear

        configureProgressLayer()
        applyProgressColor()
    }

    open func configureProgressLayer() {
        let progressLayer = CAShapeLayer()
        layer.addSublayer(progressLayer)
        self.progressLayer = progressLayer
    }

    // MARK: Layout

    override open func layoutSubviews() {
        super.layoutSubviews()

        progressLayer.frame = layer.bounds

        applyPath()
    }

    // MARK: Drawing & Style

    override open func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        let drawingPath = createShapePathFor(progress: 1.0)
        context.addPath(drawingPath.cgPath)
        context.setFillColor(fillColor.cgColor)
        context.fillPath()
    }

    open func applyProgressColor() {
        progressLayer.fillColor = progressColor.cgColor
    }

    open func applyPath() {
        progressLayer.path = createShapePathFor(progress: progress).cgPath
    }

    private func createShapePathFor(progress: CGFloat) -> UIBezierPath {
        let size = CGSize(width: bounds.size.width * progress, height: bounds.size.height)
        let rect = CGRect(origin: CGPoint.zero, size: size)
        return UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
    }
}
