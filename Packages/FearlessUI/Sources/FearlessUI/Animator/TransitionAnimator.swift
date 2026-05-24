/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

public final class TransitionAnimator: ViewAnimatorProtocol {
    public var duration: TimeInterval
    public var type: CATransitionType
    public var subtype: CATransitionSubtype?
    public var curve: CAMediaTimingFunctionName?

    public init(type: CATransitionType,
                duration: TimeInterval = 0.25,
                subtype: CATransitionSubtype? = nil,
                curve: CAMediaTimingFunctionName? = nil) {
        self.type = type
        self.duration = duration
        self.subtype = subtype
        self.curve = curve
    }

    public func animate(view: UIView, completionBlock: ((Bool) -> Void)?) {
        CATransaction.begin()

        let animation = CATransition()
        animation.type = type
        animation.duration = duration
        animation.subtype = subtype

        if let curve = curve {
            animation.timingFunction = CAMediaTimingFunction(name: curve)
        }

        view.layer.add(animation, forKey: nil)

        if let completion = completionBlock {
            CATransaction.setCompletionBlock {
                completion(true)
            }
        }

        CATransaction.commit()
    }
}
