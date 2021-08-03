import UIKit
import SoraUI

public struct TriangularedCorners: OptionSet {
    public typealias RawValue = UInt8

    static let none: TriangularedCorners = []
    static let topLeft = TriangularedCorners(rawValue: 1)
    static let bottomRight = TriangularedCorners(rawValue: 2)

    public var rawValue: TriangularedCorners.RawValue

    public init(rawValue: TriangularedCorners.RawValue) {
        self.rawValue = rawValue
    }
}

/**
    Subclass of ShadowShapeView designed to provided view with rounded corners.
 */

open class TriangularedView: ShadowShapeView {
    /// Side of the triangle that cuts the corners. Defaults `10.0`
    @IBInspectable
    open var sideLength: CGFloat = 10.0 {
        didSet {
            applyPath()
        }
    }

    /// Controls which corners should be cut. By default top left and bottom right.
    open var cornerCut: TriangularedCorners = [.topLeft, .bottomRight] {
        didSet {
            applyPath()
        }
    }

    // MARK: Overriden methods

    override open var shapePath: UIBezierPath {
        let bezierPath = UIBezierPath()

        let layerBounds: CGRect = bounds

        if cornerCut.contains(.topLeft) {
            bezierPath.move(to: CGPoint(x: layerBounds.minX + sideLength, y: layerBounds.minY))
        } else {
            bezierPath.move(to: CGPoint(x: layerBounds.minX, y: layerBounds.minY))
        }

        bezierPath.addLine(to: CGPoint(x: layerBounds.maxX, y: layerBounds.minY))

        if cornerCut.contains(.bottomRight) {
            bezierPath.addLine(to: CGPoint(x: layerBounds.maxX, y: layerBounds.maxY - sideLength))
            bezierPath.addLine(to: CGPoint(x: layerBounds.maxX - sideLength, y: layerBounds.maxY))
        } else {
            bezierPath.addLine(to: CGPoint(x: layerBounds.maxX, y: layerBounds.maxY))
        }

        bezierPath.addLine(to: CGPoint(x: layerBounds.minX, y: layerBounds.maxY))

        if cornerCut.contains(.topLeft) {
            bezierPath.addLine(to: CGPoint(x: layerBounds.minX, y: layerBounds.minY + sideLength))
            bezierPath.addLine(to: CGPoint(x: layerBounds.minX + sideLength, y: layerBounds.minY))
        } else {
            bezierPath.addLine(to: CGPoint(x: layerBounds.minX, y: layerBounds.minY))
        }

        return bezierPath
    }
}
