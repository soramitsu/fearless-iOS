import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public struct ModalSheetPresentationHeaderStyle {
    public let preferredHeight: CGFloat
    public let backgroundColor: UIColor
    public let cornerRadius: CGFloat
    public let indicatorVerticalOffset: CGFloat
    public let indicatorSize: CGSize
    public let indicatorColor: UIColor

    public init(preferredHeight: CGFloat,
                backgroundColor: UIColor,
                cornerRadius: CGFloat,
                indicatorVerticalOffset: CGFloat,
                indicatorSize: CGSize,
                indicatorColor: UIColor) {
        self.preferredHeight = preferredHeight
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.indicatorVerticalOffset = indicatorVerticalOffset
        self.indicatorSize = indicatorSize
        self.indicatorColor = indicatorColor
    }
}

public struct ModalSheetPresentationStyle {
    public let backdropColor: UIColor
    public let headerStyle: ModalSheetPresentationHeaderStyle?

    public init(backdropColor: UIColor, headerStyle: ModalSheetPresentationHeaderStyle? = nil) {
        self.backdropColor = backdropColor
        self.headerStyle = headerStyle
    }
}

public extension ModalSheetPresentationStyle {
    static var defaultStyle: ModalSheetPresentationStyle {
        ModalSheetPresentationStyle(backdropColor: UIColor.black.withAlphaComponent(0.5), headerStyle: nil)
    }
}
