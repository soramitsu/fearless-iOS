import UIKit
import SoraUI

/**
    Subclass of ShadowShapeView designed to provided view with rounded corners.
 */

class TriangularedView: ShadowShapeView {
    /// Side of the triangle that cuts the corners. Defaults `8.0`
    @IBInspectable
    open var sideLength: CGFloat = 8.0 {
        didSet {
            applyPath()
        }
    }

    // MARK: Overriden methods
    override open var shapePath: UIBezierPath {
        let bezierPath = UIBezierPath()
        bezierPath.move(to: CGPoint(x: bounds.minX + sideLength, y: bounds.minY))
        bezierPath.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
        bezierPath.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY - sideLength))
        bezierPath.addLine(to: CGPoint(x: bounds.maxX - sideLength, y: bounds.maxY))
        bezierPath.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        bezierPath.addLine(to: CGPoint(x: bounds.minX, y: sideLength))
        bezierPath.addLine(to: CGPoint(x: bounds.minX + sideLength, y: bounds.minY))
        return bezierPath
    }
}
