/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

/**
    Subclass of ShapeView designed to allow shadow display.
 */

open class ShadowShapeView: ShapeView {
    /// Default value is `1.0`. Set it to `0.0` to prevent shadow drawing.
    @IBInspectable
    open var shadowOpacity: Float = 1.0 {
        didSet {
            applyShadowOpacity()
        }
    }

    /// Default value is `UIColor.black`.
    @IBInspectable
    open var shadowColor: UIColor = UIColor.black {
        didSet {
            applyShadowColor()
        }
    }

    /// Default value is `3.0`.
    @IBInspectable
    open var shadowRadius: CGFloat = 3.0 {
        didSet {
            applyShadowRadius()
        }
    }

    /// Default offset is `(0.0, -3.0)`.
    @IBInspectable
    open var shadowOffset: CGSize = CGSize(width: 0.0, height: -3.0) {
        didSet {
            applyShadowOffset()
        }
    }

    // MARK: Layout methods

    override open func layoutSubviews() {
        super.layoutSubviews()

        applyShadowPath()
    }

    // MARK: Layer style methods
    override open func applyLayerStyle() {
        super.applyLayerStyle()

        applyShadowOpacity()
        applyShadowColor()
        applyShadowRadius()
        applyShadowOffset()
        applyShadowPath()
    }

    private func applyShadowOpacity() {
        if let layer = self.layer as? CAShapeLayer {
            layer.shadowOpacity = self.shadowOpacity
        }
    }

    private func applyShadowColor() {
        if let layer = self.layer as? CAShapeLayer {
            layer.shadowColor = self.shadowColor.cgColor
        }
    }

    private func applyShadowRadius() {
        if let layer = self.layer as? CAShapeLayer {
            layer.shadowRadius = self.shadowRadius
        }
    }

    private func applyShadowOffset() {
        if let layer = self.layer as? CAShapeLayer {
            layer.shadowOffset = self.shadowOffset
        }
    }

    private func applyShadowPath() {
        if let layer = self.layer as? CAShapeLayer {
            layer.shadowPath = self.shapePath.cgPath
        }
    }
}
