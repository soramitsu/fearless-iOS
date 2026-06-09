import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public final class MultilineSkeleton {
    let startLinePosition: CGPoint
    let lineSize: CGSize
    let count: UInt8
    let spacing: CGFloat

    private(set) var cornerRadii: CGSize?
    private(set) var cornerRoundingMode: UIRectCorner?

    private(set) var startColor: UIColor?
    private(set) var endColor: UIColor?

    private(set) var lastLineFraction: CGFloat = 1.0

    public init(startLinePosition: CGPoint, lineSize: CGSize, count: UInt8, spacing: CGFloat) {
        self.startLinePosition = startLinePosition
        self.lineSize = lineSize
        self.count = count
        self.spacing = spacing
    }

    public func round(_ cornerRadii: CGSize = CGSize(width: 0.5, height: 0.5),
                      mode: UIRectCorner = .allCorners) -> Self {
        self.cornerRadii = cornerRadii
        self.cornerRoundingMode = mode

        return self
    }

    public func fillStart(_ color: UIColor) -> Self {
        startColor = color

        return self
    }

    public func fillEnd(_ color: UIColor) -> Self {
        endColor = color

        return self
    }

    public func lastLine(fraction: CGFloat) -> Self {
        lastLineFraction = fraction
        return self
    }
}

extension MultilineSkeleton: Skeletonable {
    public var skeletons: [Skeleton] {
        return (0..<count).map { (index) in
            let skeletonSize: CGSize
            let position: CGPoint

            if index < count - 1 {
                skeletonSize = lineSize
                position = CGPoint(x: startLinePosition.x,
                                   y: startLinePosition.y + CGFloat(index) * (skeletonSize.height + spacing))
            } else {
                skeletonSize = CGSize(width: lineSize.width * lastLineFraction,
                                      height: lineSize.height)
                position = CGPoint(x: startLinePosition.x - lineSize.width / 2.0 + skeletonSize.width / 2.0,
                                   y: startLinePosition.y + CGFloat(index) * (skeletonSize.height + spacing))
            }

            return Skeleton(position: position,
                            size: skeletonSize,
                            cornerRadii: cornerRadii,
                            cornerRoundingMode: cornerRoundingMode,
                            startColor: startColor,
                            endColor: endColor)
        }
    }
}
