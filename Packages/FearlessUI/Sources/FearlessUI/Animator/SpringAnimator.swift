/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

public final class SpringAnimator {
    public private(set) var duration: TimeInterval
    public private(set) var dampingFactor: CGFloat
    public private(set) var initialVelocity: CGFloat
    public private(set) var initialScale: CGFloat

    public init(duration: TimeInterval = 0.5,
                dampingFactor: CGFloat = 0.5,
                initialVelocity: CGFloat = 0.1,
                initialScale: CGFloat = 2.0) {
        self.duration = duration
        self.dampingFactor = dampingFactor
        self.initialVelocity = initialVelocity
        self.initialScale = initialScale
    }
}

extension SpringAnimator: ViewAnimatorProtocol {
    public func animate(view: UIView, completionBlock: ((Bool) -> Void)?) {
        view.transform = CGAffineTransform(scaleX: initialScale,
                                           y: initialScale)

        let animationBlock = {
            view.transform = CGAffineTransform.identity
        }

        UIView.animate(withDuration: duration,
                       delay: 0.0,
                       usingSpringWithDamping: dampingFactor,
                       initialSpringVelocity: initialVelocity,
                       options: .curveLinear,
                       animations: animationBlock, completion: completionBlock)
    }
}
