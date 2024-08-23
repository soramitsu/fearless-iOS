import Foundation
import UIKit

private enum Constants {
    static let gradientStartPoint = CGPoint(x: 0.0, y: 0.5)
    static let gradientEndPoint = CGPoint(x: 1.0, y: 0.5)
    static let animationStartPositions: [NSNumber] = [-1.0, -0.55, -0.45, 0.0]
    static let animationEndPositions: [NSNumber] = [1.0, 1.45, 1.55, 2.0]
    static let animationDuration: TimeInterval = 1.4
    static let colorSkeletonStart = R.color.colorSkeletonStart()!.cgColor
    static let colorSkeletonEnd = R.color.colorSkeletonEnd()!.cgColor
    static let animationKey = "location.animation.\(UUID().uuidString)"
}

protocol ShimmeredProtocol: UIView {
    func startShimmeringAnimation()
    func stopShimmeringAnimation()
}

extension ShimmeredProtocol {
    func startShimmeringAnimation() {
        layoutIfNeeded()
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            Constants.colorSkeletonStart,
            Constants.colorSkeletonEnd,
            Constants.colorSkeletonStart
        ]
        gradientLayer.frame = CGRect(
            x: -bounds.size.width,
            y: -bounds.size.height,
            width: bounds.size.width * 3,
            height: bounds.size.height * 3
        )

        gradientLayer.startPoint = Constants.gradientStartPoint
        gradientLayer.endPoint = Constants.gradientEndPoint
        gradientLayer.locations = Constants.animationStartPositions
        layer.mask = gradientLayer

        CATransaction.begin()
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = Constants.animationStartPositions
        animation.toValue = Constants.animationEndPositions
        animation.duration = Constants.animationDuration
        animation.repeatCount = MAXFLOAT
        gradientLayer.add(animation, forKey: Constants.animationKey)
        CATransaction.commit()
    }

    func stopShimmeringAnimation() {
        layer.mask = nil
        layer.removeAnimation(forKey: Constants.animationKey)
    }
}
