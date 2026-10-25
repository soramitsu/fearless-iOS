import UIKit

/// Fearless cuts the top-left and bottom-right corners, regardless of text direction.
enum FWChamferPath {
    static func path(in bounds: CGRect, cut: CGFloat = FWTokens.Chamfer.mCut, radius: CGFloat = FWTokens.Chamfer.mRadius) -> UIBezierPath {
        let limit = max(0, min(bounds.width, bounds.height) / 2)
        let cut = min(max(0, cut), limit)
        let radius = min(max(0, radius), limit)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: bounds.minX + cut, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX - radius, y: bounds.minY))
        path.addQuadCurve(to: CGPoint(x: bounds.maxX, y: bounds.minY + radius), controlPoint: CGPoint(x: bounds.maxX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY - cut))
        path.addLine(to: CGPoint(x: bounds.maxX - cut, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX + radius, y: bounds.maxY))
        path.addQuadCurve(to: CGPoint(x: bounds.minX, y: bounds.maxY - radius), controlPoint: CGPoint(x: bounds.minX, y: bounds.maxY))
        path.addLine(to: CGPoint(x: bounds.minX, y: bounds.minY + cut))
        path.close()
        return path
    }
}
