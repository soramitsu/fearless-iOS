import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol ListViewLayoutStrategyProtocol: AnyObject {
    func layout(views: [UIView], in rect: CGRect)
}

public final class HorizontalEqualWidthLayoutStrategy: ListViewLayoutStrategyProtocol {
    public init() {}

    public func layout(views: [UIView], in rect: CGRect) {
        guard views.count > 0 else {
            return
        }

        let viewWidth = rect.size.width / CGFloat(views.count)

        for (index, view) in views.enumerated() {
            view.frame = CGRect(x: rect.origin.x + CGFloat(index) * viewWidth,
                                y: rect.origin.y,
                                width: viewWidth,
                                height: rect.size.height)
        }
    }
}

public final class HorizontalFlexibleLayoutStrategy: ListViewLayoutStrategyProtocol {
    public private(set) var margin: CGFloat

    public init(margin: CGFloat = 0.0) {
        self.margin = margin
    }

    public func layout(views: [UIView], in rect: CGRect) {
        let targetSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: rect.size.height)

        let viewWidthList = views.map {
            return $0.sizeThatFits(targetSize).width + 2 * self.margin
        }

        let totalContentWidth: CGFloat = viewWidthList.reduce(0.0) { $0 + $1 }

        guard totalContentWidth > 0.0 else {
            return
        }

        var offsetX = rect.origin.x
        let ratio = rect.width / totalContentWidth

        for (index, view) in views.enumerated() {
            let width = viewWidthList[index] * ratio

            view.frame = CGRect(x: offsetX,
                                y: rect.origin.y,
                                width: width,
                                height: rect.size.height)

            offsetX += width
        }
    }
}
