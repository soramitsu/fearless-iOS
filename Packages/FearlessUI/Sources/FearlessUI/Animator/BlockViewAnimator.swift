/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

public protocol BlockViewAnimatorProtocol {
    var duration: TimeInterval { get }

    func animate(block: @escaping () -> Void, completionBlock: ((Bool) -> Void)?)
}

public final class BlockViewAnimator: BlockViewAnimatorProtocol {
    public private(set) var duration: TimeInterval
    public private(set) var delay: TimeInterval
    public private(set) var options: UIView.AnimationOptions

    public init(duration: TimeInterval = 0.25, delay: TimeInterval = 0.0, options: UIView.AnimationOptions = .curveLinear) {
        self.duration = duration
        self.options = options
        self.delay = delay
    }

    public func animate(block: @escaping () -> Void, completionBlock: ((Bool) -> Void)?) {
        UIView.animate(withDuration: duration,
                       delay: delay,
                       options: options,
                       animations: block,
                       completion: completionBlock)
    }
}
