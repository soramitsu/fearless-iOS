import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL 3.0
*/

import Foundation

public enum ModalAlertCompletionFeedback {
    case none
    case success
    case warning
    case error
}

public struct ModalAlertPresentationConfiguration {
    public let contentAppearanceAnimator: ViewAnimatorProtocol
    public let contentDissmisalAnimator: ViewAnimatorProtocol
    public let style: ModalAlertPresentationStyle
    public let contentOffset: UIEdgeInsets
    public let preferredSize: CGSize
    public let dismissAfterDelay: TimeInterval
    public let completionFeedback: ModalAlertCompletionFeedback

    public init(style: ModalAlertPresentationStyle,
                preferredSize: CGSize,
                contentAppearanceAnimator: ViewAnimatorProtocol = FadeAnimator(from: 0.0, to: 1.0),
                contentDissmisalAnimator: ViewAnimatorProtocol = FadeAnimator(from: 1.0, to: 0.0),
                contentOffset: UIEdgeInsets = .zero,
                dismissAfterDelay: TimeInterval = 1.5,
                completionFeedback: ModalAlertCompletionFeedback = .none) {
        self.contentAppearanceAnimator = contentAppearanceAnimator
        self.contentDissmisalAnimator = contentDissmisalAnimator
        self.style = style
        self.contentOffset = contentOffset
        self.preferredSize = preferredSize
        self.dismissAfterDelay = dismissAfterDelay
        self.completionFeedback = completionFeedback
    }
}
