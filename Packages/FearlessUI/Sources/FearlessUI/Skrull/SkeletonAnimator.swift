import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

protocol SkeletonAnimatorProtocol {
    func startAnimation(on layer: CAGradientLayer)
    func stopAnimation(on layer: CAGradientLayer)
}

final class LocationSkeletonAnimator: SkeletonAnimatorProtocol {
    let startLocations: [NSNumber]
    let endLocations: [NSNumber]
    let duration: TimeInterval
    let timingFunction: CAMediaTimingFunction

    let animationKey = "location.animation.\(UUID().uuidString)"

    init(startLocations: [NSNumber],
         endLocations: [NSNumber],
         duration: TimeInterval = 0.25,
         timingFunction: CAMediaTimingFunction = CAMediaTimingFunction(name: .linear)) {
        self.startLocations = startLocations
        self.endLocations = endLocations
        self.duration = duration
        self.timingFunction = timingFunction
    }

    func startAnimation(on layer: CAGradientLayer) {
        let animation = CABasicAnimation(keyPath: #keyPath(CAGradientLayer.locations))
        animation.fromValue = startLocations
        animation.toValue = endLocations
        animation.duration = duration
        animation.timingFunction = timingFunction
        animation.repeatCount = Float.infinity

        layer.add(animation, forKey: animationKey)
    }

    func stopAnimation(on layer: CAGradientLayer) {
        layer.removeAnimation(forKey: animationKey)
    }
}
