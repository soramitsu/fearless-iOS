import UIKit

class GradientBorderedTriangularedView: TriangularedView {
    lazy var gradientBorder: CAGradientLayer = {
        let mask = CAShapeLayer()
        mask.path = shapePath.cgPath
        mask.fillColor = UIColor.clear.cgColor
        mask.strokeColor = UIColor.white.cgColor
        mask.lineWidth = 1
        
        let borderLayer = CAGradientLayer()
        borderLayer.frame = bounds
        borderLayer.startPoint = gradientBorderStartPoint
        borderLayer.endPoint = gradientBorderEndPoint
        borderLayer.mask = mask
        borderLayer.colors =  UIColor.walletBorderGradientColors.map { $0.cgColor }
        
        return borderLayer
    }()
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        layer.addSublayer(gradientBorder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        (gradientBorder.mask as? CAShapeLayer)?.path = shapePath.cgPath
        gradientBorder.frame = bounds
    }
}
