/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

@IBDesignable
open class CameraFrameView: UIView {
    private var frameOverlayLayer: CAShapeLayer!

    open var frameLayer: CALayer? {
        didSet {
            oldValue?.removeFromSuperlayer()

            if let currentLayer = frameLayer {
                layer.insertSublayer(currentLayer, below: frameOverlayLayer)
                setNeedsLayout()
            }
        }
    }

    open var windowSize = CGSize(width: 100.0, height: 100.0) {
        didSet {
            updateOverlayWindow()
        }
    }

    open var windowPosition = CGPoint(x: 0.0, y: 0.0) {
        didSet {
            updateOverlayWindow()
        }
    }

    @IBInspectable
    open var cornerRadius: CGFloat = 10.0 {
        didSet {
            updateOverlayWindow()
        }
    }

    @IBInspectable
    open var fillColor: UIColor = UIColor.black.withAlphaComponent(0.5) {
        didSet {
            updateOverlayFillColor()
        }
    }

    // MARK: Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        configure()
    }

    private func configure() {
        if frameOverlayLayer == nil {
            frameOverlayLayer = CAShapeLayer()
            layer.addSublayer(frameOverlayLayer)
        }

        updateOverlayFillColor()
        updateOverlayWindow()
    }

    func updateOverlayFillColor() {
        frameOverlayLayer.fillColor = fillColor.cgColor
    }

    func updateOverlayWindow() {
        let origin = CGPoint(x: bounds.maxX * windowPosition.x - windowSize.width / 2.0,
                             y: bounds.maxY * windowPosition.y - windowSize.height / 2.0)
        let windowRect = CGRect(origin: origin, size: windowSize)
        let bezierPath = UIBezierPath(roundedRect: windowRect, cornerRadius: cornerRadius)
        bezierPath.append(UIBezierPath(rect: bounds))
        frameOverlayLayer.path = bezierPath.cgPath
        frameOverlayLayer.fillRule = .evenOdd
    }

    // MARK: Layout

    override open func layoutSubviews() {
        super.layoutSubviews()

        frameLayer?.frame = bounds

        if frameOverlayLayer?.frame != bounds {
            frameOverlayLayer?.frame = bounds
            updateOverlayWindow()
        }
    }
}

extension CameraFrameView {
    @IBInspectable
    private var _windowWidth: CGFloat {
        get {
            return windowSize.width
        }

        set {
            windowSize = CGSize(width: newValue, height: windowSize.height)
        }
    }

    @IBInspectable
    private var _windowHeight: CGFloat {
        set {
            windowSize = CGSize(width: windowSize.width, height: newValue)
        }

        get {
            return windowSize.height
        }
    }

    @IBInspectable
    private var _windowPositionX: CGFloat {
        set {
            windowPosition = CGPoint(x: newValue, y: windowPosition.y)
        }

        get {
            return windowPosition.x
        }
    }

    @IBInspectable
    private var _windowPositionY: CGFloat {
        set {
            windowPosition = CGPoint(x: windowPosition.x, y: newValue)
        }

        get {
            return windowPosition.y
        }
    }
}
