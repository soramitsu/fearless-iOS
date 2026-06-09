/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

@IBDesignable
open class GradientView: UIView {
    @IBInspectable
    open var cornerRadius: CGFloat = 0.0 {
        didSet {
            setNeedsLayout()
        }
    }

    @IBInspectable
    open var startColor: UIColor = UIColor.white {
        didSet {
            applyColors()
        }
    }

    @IBInspectable
    open var endColor: UIColor = UIColor.black {
        didSet {
            applyColors()
        }
    }

    @IBInspectable
    open var startPoint: CGPoint = CGPoint(x: 0.0, y: 0.0) {
        didSet {
            applyStartPoint()
        }
    }

    @IBInspectable
    open var endPoint: CGPoint = CGPoint(x: 0.0, y: 1.0) {
        didSet {
            applyEndPoint()
        }
    }

    @IBInspectable
    open var transitionLocation: Float = 0.5 {
        didSet {
            applyTransitionLocation()
        }
    }

    // MARK: Layer methods

    open override class var layerClass: AnyClass {
        return CAGradientLayer.self
    }

    // MARK: Initializer

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    open override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        configure()
    }

    // MARK: Layout methods

    override open func didMoveToWindow() {
        super.didMoveToWindow()

        if let window = self.window {
            layer.contentsScale = window.screen.scale
            layer.rasterizationScale = window.screen.scale
            setNeedsDisplay()
        }
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        applyMask()
    }

    // MARK: Configuration methods

    open func configure() {
        self.backgroundColor = UIColor.clear

        configureLayer()
    }

    open func configureLayer() {
        if let layer = self.layer as? CAGradientLayer {
            layer.shouldRasterize = true
            applyLayerStyle()
        }
    }

    // MARK: Layer Style methods

    open func applyLayerStyle() {
        applyColors()
        applyStartPoint()
        applyEndPoint()
        applyTransitionLocation()
    }

    private func applyColors() {
        if let layer = self.layer as? CAGradientLayer {
            layer.colors = [startColor.cgColor, endColor.cgColor]
        }
    }

    private func applyStartPoint() {
        if let layer = self.layer as? CAGradientLayer {
            layer.startPoint = startPoint
        }
    }

    private func applyEndPoint() {
        if let layer = self.layer as? CAGradientLayer {
            layer.endPoint = endPoint
        }
    }

    private func applyTransitionLocation() {
        if let layer = self.layer as? CAGradientLayer {
            layer.locations = [NSNumber(value: transitionLocation)]
        }
    }

    private func applyMask() {
        if let layer = self.layer as? CAGradientLayer {
            if cornerRadius > 0 {
                let mask = CAShapeLayer()
                mask.path = UIBezierPath(roundedRect: layer.bounds, cornerRadius: cornerRadius).cgPath
                layer.mask = mask
            } else {
                layer.mask = nil
            }
        }
    }
}
