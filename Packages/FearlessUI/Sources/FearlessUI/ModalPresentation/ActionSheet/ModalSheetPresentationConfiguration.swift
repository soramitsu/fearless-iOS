import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public struct ModalSheetPresentationConfiguration {
    public let contentAppearanceAnimator: BlockViewAnimatorProtocol
    public let contentDissmisalAnimator: BlockViewAnimatorProtocol
    public let style: ModalSheetPresentationStyle

    public let extendUnderSafeArea: Bool
    public let dismissPercentThreshold: CGFloat
    public let dismissVelocityThreshold: CGFloat
    public let dismissMinimumOffset: CGFloat
    public let dismissFinishSpeedFactor: CGFloat
    public let dismissCancelSpeedFactor: CGFloat

    public init(contentAppearanceAnimator: BlockViewAnimatorProtocol = BlockViewAnimator(duration: 0.35, delay: 0.0, options: [.curveLinear]),
                contentDissmisalAnimator: BlockViewAnimatorProtocol = BlockViewAnimator(duration: 0.35, delay: 0.0, options: [.curveLinear]),
                style: ModalSheetPresentationStyle = .defaultStyle,
                extendUnderSafeArea: Bool = false,
                dismissPercentThreshold: CGFloat = 0.35,
                dismissVelocityThreshold: CGFloat = 1280,
                dismissMinimumOffset: CGFloat = 87,
                dismissFinishSpeedFactor: CGFloat = 0.3,
                dismissCancelSpeedFactor: CGFloat = 0.3) {
        self.contentAppearanceAnimator = contentAppearanceAnimator
        self.contentDissmisalAnimator = contentDissmisalAnimator
        self.style = style
        self.extendUnderSafeArea = extendUnderSafeArea
        self.dismissPercentThreshold = dismissPercentThreshold
        self.dismissVelocityThreshold = dismissVelocityThreshold
        self.dismissMinimumOffset = dismissMinimumOffset
        self.dismissFinishSpeedFactor = dismissFinishSpeedFactor
        self.dismissCancelSpeedFactor = dismissCancelSpeedFactor
    }

    public init(shadowOpacity: CGFloat) {
        let style = ModalSheetPresentationStyle(backdropColor: UIColor.black.withAlphaComponent(shadowOpacity))

        self.init(style: style)
    }
}
