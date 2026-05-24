/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

public struct BorderType: OptionSet {
    public typealias RawValue = UInt8

    public static var none: BorderType { return BorderType(rawValue: 0) }
    public static var left: BorderType { return BorderType(rawValue: 1 << 0) }
    public static var top: BorderType { return BorderType(rawValue: 1 << 1) }
    public static var right: BorderType { return BorderType(rawValue: 1 << 2) }
    public static var bottom: BorderType { return BorderType(rawValue: 1 << 3) }
    public static var all: BorderType {
        let rawValue = BorderType.top.rawValue |
            BorderType.bottom.rawValue |
            BorderType.left.rawValue |
            BorderType.right.rawValue
        return BorderType(rawValue: rawValue)

    }

    private(set) public var rawValue: UInt8

    public init(rawValue: BorderType.RawValue) {
        self.rawValue = rawValue
    }

    public mutating func formUnion(_ other: BorderType) {
        self.rawValue |= other.rawValue
    }

    public mutating func formIntersection(_ other: BorderType) {
        self.rawValue &= other.rawValue
    }

    public mutating func formSymmetricDifference(_ other: BorderType) {
        self.rawValue ^= other.rawValue
    }
}

public class BorderedContainerView: ShadowShapeView {
    public var borderType = BorderType.all {
        didSet {
            applyPath()
        }
    }

    public var lineCap = CGLineCap.butt {
        didSet {
            applyLineCap()
        }
    }

    public override var shapePath: UIBezierPath {
        let bezierPath = UIBezierPath()
        let boundsOrigin = self.bounds.origin
        let boundsSize = self.bounds.size

        if borderType.contains(BorderType.top) {
            bezierPath.move(to: boundsOrigin)
            bezierPath.addLine(to: CGPoint(x: boundsOrigin.x + boundsSize.width, y: boundsOrigin.y))
        }

        if borderType.contains(BorderType.left) {
            bezierPath.move(to: boundsOrigin)
            bezierPath.addLine(to: CGPoint(x: boundsOrigin.x, y: boundsOrigin.y + boundsSize.height))
        }

        if borderType.contains(BorderType.bottom) {
            bezierPath.move(to: CGPoint(x: boundsOrigin.x, y: boundsOrigin.y + boundsSize.height))
            bezierPath.addLine(to: CGPoint(x: boundsOrigin.x + boundsSize.width, y: boundsOrigin.y + boundsSize.height))
        }

        if borderType.contains(BorderType.right) {
            bezierPath.move(to: CGPoint(x: boundsOrigin.x + boundsSize.width, y: boundsOrigin.y))
            bezierPath.addLine(to: CGPoint(x: boundsOrigin.x + boundsSize.width, y: boundsOrigin.y + boundsSize.height))
        }

        return bezierPath
    }

    // MARK: Layer style methods
    override public func applyLayerStyle() {
        super.applyLayerStyle()
        applyLineCap()
    }

    private func applyLineCap() {
        if let shapeLayer = self.layer as? CAShapeLayer {
            switch lineCap {
            case .butt:
                shapeLayer.lineCap = CAShapeLayerLineCap.butt
            case .round:
                shapeLayer.lineCap = CAShapeLayerLineCap.round
            case .square:
                shapeLayer.lineCap = CAShapeLayerLineCap.square
            @unknown default:
                shapeLayer.lineCap = CAShapeLayerLineCap.butt
            }
        }
    }
}

@IBDesignable
extension BorderedContainerView {
    @IBInspectable
    private var _topBorder: Bool {
        get {
            return borderType.contains(BorderType.top)
        }

        set(newValue) {
            if newValue {
                borderType.formUnion(BorderType.top)
            } else {
                borderType.remove(BorderType.top)
            }
        }
    }

    @IBInspectable
    private var _leftBorder: Bool {
        get {
            return borderType.contains(BorderType.left)
        }

        set(newValue) {
            if newValue {
                borderType.formUnion(BorderType.left)
            } else {
                borderType.remove(BorderType.left)
            }
        }
    }

    @IBInspectable
    private var _bottomBorder: Bool {
        get {
            return borderType.contains(BorderType.bottom)
        }

        set(newValue) {
            if newValue {
                borderType.formUnion(BorderType.bottom)
            } else {
                borderType.remove(BorderType.bottom)
            }
        }
    }

    @IBInspectable
    private var _rightBorder: Bool {
        get {
            return borderType.contains(BorderType.right)
        }

        set(newValue) {
            if newValue {
                borderType.formUnion(BorderType.right)
            } else {
                borderType.remove(BorderType.right)
            }
        }
    }

    @IBInspectable
    private var _lineCap: Int32 {
        get {
            return lineCap.rawValue
        }

        set(newValue) {
            if let newLineCap = CGLineCap(rawValue: newValue) {
                self.lineCap = newLineCap
            }
        }
    }
}
