/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

public final class TransformAnimator: ViewAnimatorProtocol {
    public private(set) var fromTransform: CGAffineTransform
    public private(set) var toTransform: CGAffineTransform
    public private(set) var duration: TimeInterval
    public private(set) var delay: TimeInterval
    public private(set) var options: UIView.AnimationOptions

    public init(from fromTransform: CGAffineTransform,
         to toTransform: CGAffineTransform,
         duration: TimeInterval = 0.25,
         delay: TimeInterval = 0.0,
         options: UIView.AnimationOptions = .curveLinear) {
        self.fromTransform = fromTransform
        self.toTransform = toTransform
        self.duration = duration
        self.delay = delay
        self.options = options
    }

    public func animate(view: UIView, completionBlock: ((Bool) -> Void)?) {
        view.transform = fromTransform

        UIView.animate(withDuration: duration,
                       delay: delay,
                       options: options,
                       animations: { view.transform = self.toTransform },
                       completion: completionBlock)
    }
}
