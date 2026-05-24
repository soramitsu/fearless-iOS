/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

/**
    Subclass of ShapeView designed to provided interface for `CAShapeLayer`.
    By default shape is represented by rectangle covering entire bounds.
    Consider overriding `shapePath` method in subclass to change the behavior.
    By default layer is rasterized and scale is inherited from the window.

    View supports `@IBDesignable` protocol to design throw Interface Builder.
 */

@IBDesignable
open class ShapeView: UIView, Highlightable {
    private struct Constants {
        static let fillColorAnimationKey = "fillColorAnimationKey"
        static let strokeColorAnimationKey = "strokeColorAnimationKey"
    }

    /// By default `UIColor.white`.
    @IBInspectable
    open var fillColor: UIColor = UIColor.white {
        didSet {
            if !isHighlighted { applyFillColor() }
        }
    }

    /// By default `UIColor.gray`.
    @IBInspectable
    open var highlightedFillColor: UIColor = UIColor.gray {
        didSet {
            if isHighlighted { applyFillColor() }
        }
    }

    /// By default `UIColor.gray`.
    @IBInspectable
    open var strokeColor: UIColor = UIColor.gray {
        didSet {
            if !isHighlighted { applyStrokeColor() }
        }
    }

    /// By default `UIColor.gray`.
    @IBInspectable
    open var highlightedStrokeColor: UIColor = UIColor.white {
        didSet {
            if isHighlighted { applyStrokeColor() }
        }
    }

    /// By default `0.0`.
    @IBInspectable
    open var strokeWidth: CGFloat = 0.0 {
        didSet {
            applyStrokeWidth()
        }
    }

    /// By default rectangle that fills the entire bounds.
    open var shapePath: UIBezierPath {
        return UIBezierPath(rect: self.bounds)
    }

    /// By default `false`.
    @IBInspectable
    open var isHighlighted: Bool = false {
        didSet {
            applyLayerStyle()
        }
    }

    /// Duration of highlight animation
    open var highlightableAnimationDuration: TimeInterval = 0.5

    // Additional options of highligh animation
    open var highlightableTimingOption: CAMediaTimingFunctionName = .easeOut

    /// Highlightable protocol implementation that is used to animate highlighted state changes
    open func set(highlighted: Bool, animated: Bool) {
        cancelLayerStyleAnimation()

        isHighlighted = highlighted

        if animated {
            animateLayerStyle(to: highlighted)
        }
    }

    // MARK: Layer methods

    open override class var layerClass: AnyClass {
        return CAShapeLayer.self
    }

    // MARK: Initializers

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    override open func prepareForInterfaceBuilder() {
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

        applyPath()
    }

    // MARK: Configuration methods

    /**
        Override this method to provide additional configuration for view in subclass.
        Super implementation **must be** called at some point.
        This method is **not supposed** to be called outside of the class.
        If configuration of layer need to be customized consider to override `configureLayer`
        or `applyLayerStyle` instead.
    */
    open func configure() {
        self.backgroundColor = UIColor.clear

        configureLayer()
    }

    /**
        Override this method to provide additional configuration for layer in subclass.
        Super implementation **must be** called at some point.
        This method is **not supposed** to be called outside of the class.
        If configuration of the view itself need to be customized consider to override `configure` instead.
     */
    open func configureLayer() {
        if let layer = self.layer as? CAShapeLayer {
            layer.shouldRasterize = true
            applyLayerStyle()
        }
    }

    // MARK: Layer style methods

    /**
        Override this method to provide additional configuration for layer in subclass.
        Super implementation **must be** called at some point.
        This method is **not supposed** to be called outside of the class.
        If configuration of the view itself need to be customized consider to override `configure` instead.
     */
    open func applyLayerStyle() {
        applyFillColor()
        applyStrokeColor()
        applyStrokeWidth()
        applyPath()
    }

    /**
        Ovveride this method to customize layer style animation. Typically in this case you also need
        to consider ```cancelAnimationLayerStyle```.
    */
    open func animateLayerStyle(to highlighted: Bool) {
        CATransaction.begin()

        animateFillColor(to: highlighted)
        animateStrokeColor(to: highlighted)

        CATransaction.commit()
    }

    /**
        Ovveride this method to customize layer style animation cancel logic.
        Typically in this case you start customization from ```animateLayerStyle```.
     */
    open func cancelLayerStyleAnimation() {
        if let layer = self.layer as? CAShapeLayer {
            layer.removeAnimation(forKey: Constants.fillColorAnimationKey)
            layer.removeAnimation(forKey: Constants.strokeColorAnimationKey)
        }
    }

    /**
        Consider to call this method in subclass to update shape path when one of the properties it relates on changes.
        If you need to change shape path logic itself consider to override `shapePath` instead.
    */
    open func applyPath() {
        if let layer = self.layer as? CAShapeLayer {
            layer.path = self.shapePath.cgPath
        }
    }

    private func applyFillColor() {
        if let layer = self.layer as? CAShapeLayer {
            layer.fillColor = isHighlighted ? highlightedFillColor.cgColor : fillColor.cgColor
        }
    }

    private func animateFillColor(to highlighted: Bool) {
        if let layer = self.layer as? CAShapeLayer {
            let animation = CABasicAnimation(keyPath: "fillColor")
            animation.fromValue = !highlighted ? highlightedFillColor.cgColor : fillColor.cgColor
            animation.toValue = highlighted ? highlightedFillColor.cgColor : fillColor.cgColor
            animation.duration = highlightableAnimationDuration
            animation.timingFunction = CAMediaTimingFunction(name: highlightableTimingOption)
            layer.add(animation, forKey: Constants.fillColorAnimationKey)
        }
    }

    private func applyStrokeColor() {
        if let layer = self.layer as? CAShapeLayer {
            layer.strokeColor = isHighlighted ? highlightedStrokeColor.cgColor : strokeColor.cgColor
        }
    }

    private func animateStrokeColor(to highlighted: Bool) {
        if let layer = self.layer as? CAShapeLayer {
            let animation = CABasicAnimation(keyPath: "strokeColor")
            animation.fromValue = !highlighted ? highlightedStrokeColor.cgColor : strokeColor.cgColor
            animation.toValue = highlighted ? highlightedStrokeColor.cgColor : strokeColor.cgColor
            animation.duration = highlightableAnimationDuration
            animation.timingFunction = CAMediaTimingFunction(name: highlightableTimingOption)
            layer.add(animation, forKey: Constants.strokeColorAnimationKey)
        }
    }

    private func applyStrokeWidth() {
        if let layer = self.layer as? CAShapeLayer {
            layer.lineWidth = strokeWidth
        }
    }

}
