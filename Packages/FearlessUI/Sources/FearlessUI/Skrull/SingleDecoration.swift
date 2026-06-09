import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public final class SingleDecoration {
    let position: CGPoint
    let size: CGSize

    private(set) var cornerRadii: CGSize?
    private(set) var cornerRoundingMode: UIRectCorner?

    private(set) var fillColor: UIColor?

    private(set) var strokeColor: UIColor?
    private(set) var strokeWidth: CGFloat?

    private(set) var shadowColor: UIColor?
    private(set) var shadowOffset: CGSize?
    private(set) var shadowRadius: CGFloat?

    public var shouldFill: Bool {
        return fillColor != nil
    }

    public var shouldStroke: Bool {
        return strokeColor != nil
    }

    public init(position: CGPoint, size: CGSize) {
        self.position = position
        self.size = size
    }

    public func round(_ cornerRadii: CGSize = CGSize(width: 0.5, height: 0.5),
                      mode: UIRectCorner = .allCorners) -> Self {
        self.cornerRadii = cornerRadii
        self.cornerRoundingMode = mode

        return self
    }

    public func fill(_ color: UIColor) -> Self {
        fillColor = color

        return self
    }

    public func stroke(_ color: UIColor, width: CGFloat = 1.0) -> Self {
        self.strokeColor = color
        self.strokeWidth = width

        return self
    }

    public func shadow(_ color: UIColor, offset: CGSize, radius: CGFloat) -> Self {
        shadowColor = color
        shadowOffset = offset
        shadowRadius = radius

        return self
    }
}

extension SingleDecoration: Decorable {
    public var decorations: [Decoration] {
        return [
            Decoration(position: position,
                       size: size,
                       cornerRadii: cornerRadii,
                       cornerRoundingMode: cornerRoundingMode,
                       fillColor: fillColor,
                       strokeColor: strokeColor,
                       strokeWidth: strokeWidth,
                       shadowColor: shadowColor,
                       shadowOffset: shadowOffset,
                       shadowRadius: shadowRadius)
        ]
    }
}
