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

    var gradientBorderColors: [UIColor] = []
    var gradientBorderStartPoint = CGPoint(x: 0.0, y: 0.5)
    var gradientBorderEndPoint = CGPoint(x: 1.0, y: 0.5)

    // MARK: Overriden methods

    override open var shapePath: UIBezierPath {
        let bezierPath = UIBezierPath()

        let layerBounds: CGRect = bounds

        if cornerCut.contains(.topLeft) {
            bezierPath.move(to: CGPoint(x: layerBounds.minX + sideLength, y: layerBounds.minY))
        } else {
            bezierPath.move(to: CGPoint(x: layerBounds.minX, y: layerBounds.minY + sideLength))
            bezierPath.addQuadCurve(
                to: CGPoint(x: layerBounds.minX + sideLength, y: layerBounds.minY),
                controlPoint: CGPoint(x: layerBounds.minX, y: layerBounds.minY)
            )
        }

        bezierPath.addLine(to: CGPoint(x: layerBounds.maxX - sideLength, y: layerBounds.minY))
        bezierPath.addQuadCurve(
            to: CGPoint(x: layerBounds.maxX, y: layerBounds.minY + sideLength),
            controlPoint: CGPoint(x: layerBounds.maxX, y: layerBounds.minY)
        )

        if cornerCut.contains(.bottomRight) {
            bezierPath.addLine(to: CGPoint(x: layerBounds.maxX, y: layerBounds.maxY - sideLength))
            bezierPath.addLine(to: CGPoint(x: layerBounds.maxX - sideLength, y: layerBounds.maxY))
        } else {
            bezierPath.addLine(to: CGPoint(x: layerBounds.maxX, y: layerBounds.maxY - sideLength))
            bezierPath.addQuadCurve(
                to: CGPoint(x: layerBounds.maxX - sideLength, y: layerBounds.maxY),
                controlPoint: CGPoint(x: layerBounds.maxX, y: layerBounds.maxY)
            )
        }

        bezierPath.addLine(to: CGPoint(x: layerBounds.minX + sideLength, y: layerBounds.maxY))
        bezierPath.addQuadCurve(
            to: CGPoint(x: layerBounds.minX, y: layerBounds.maxY - sideLength),
            controlPoint: CGPoint(x: layerBounds.minX, y: layerBounds.maxY)
        )
        if cornerCut.contains(.topLeft) {
            bezierPath.addLine(to: CGPoint(x: layerBounds.minX, y: layerBounds.minY + sideLength))
            bezierPath.addLine(to: CGPoint(x: layerBounds.minX + sideLength, y: layerBounds.minY))
        } else {
            bezierPath.addLine(to: CGPoint(x: layerBounds.minX, y: layerBounds.minY + sideLength))
        }

        return bezierPath
    }
}

extension TriangularedView {
    private static let kLayerNameGradientBorder = "GradientBorderLayer"

    func setGradientBorder(highlighted: Bool, animated: Bool) {
        let border = gradientBorderLayer()
        border.frame = bounds
        border.startPoint = gradientBorderStartPoint
        border.endPoint = gradientBorderEndPoint

        let mask = CAShapeLayer()
        mask.path = shapePath.cgPath
        mask.fillColor = UIColor.clear.cgColor
        mask.strokeColor = UIColor.white.cgColor
        mask.lineWidth = strokeWidth
        border.mask = mask
        border.colors = highlighted ? gradientBorderColors.map { $0.cgColor } : [UIColor.clear].map { $0.cgColor }

        if animated {
            clearGradientAnimation()
            animateGradientColor(border: border, to: highlighted)
        }
    }

    private func gradientBorderLayer() -> CAGradientLayer {
        let borderLayers = layer.sublayers?.filter { $0.name == Self.kLayerNameGradientBorder }
        if borderLayers?.count ?? 0 > 1 {
            fatalError()
        }
        guard let border = borderLayers?.first as? CAGradientLayer else {
            let newBorder = CAGradientLayer()
            newBorder.name = Self.kLayerNameGradientBorder
            layer.addSublayer(newBorder)
            return newBorder
        }
        return border
    }

    private func animateGradientColor(border: CAGradientLayer, to highlighted: Bool) {
        let animation = CABasicAnimation(keyPath: "strokeColor")
        animation.fromValue = !highlighted ? gradientBorderColors.map { $0.cgColor } : [UIColor.clear].map { $0.cgColor }
        animation.toValue = highlighted ? gradientBorderColors.map { $0.cgColor } : [UIColor.clear].map { $0.cgColor }
        animation.duration = highlightableAnimationDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        border.add(animation, forKey: "gradientAnimationKay")
    }

    private func clearGradientAnimation() {
        if let layer = self.layer as? CAGradientLayer {
            layer.removeAnimation(forKey: "gradientAnimationKay")
        }
    }
}
