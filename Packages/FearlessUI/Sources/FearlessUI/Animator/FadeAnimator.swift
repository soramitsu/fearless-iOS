import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL 3.0
*/

import Foundation

public final class FadeAnimator: ViewAnimatorProtocol {
    public private(set) var fromValue: CGFloat
    public private(set) var toValue: CGFloat
    public private(set) var duration: TimeInterval
    public private(set) var delay: TimeInterval
    public private(set) var options: UIView.AnimationOptions

    public init(from fromValue: CGFloat,
         to toValue: CGFloat,
         duration: TimeInterval = 0.25,
         delay: TimeInterval = 0.0,
         options: UIView.AnimationOptions = .curveLinear) {
        self.fromValue = fromValue
        self.toValue = toValue
        self.duration = duration
        self.delay = delay
        self.options = options
    }

    public func animate(view: UIView, completionBlock: ((Bool) -> Void)?) {
        view.alpha = fromValue

        UIView.animate(withDuration: duration,
                       delay: delay,
                       options: options,
                       animations: { view.alpha = self.toValue },
                       completion: completionBlock)
    }
}
