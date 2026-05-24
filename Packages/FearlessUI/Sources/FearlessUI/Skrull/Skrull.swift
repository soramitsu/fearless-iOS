import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public typealias SkrullableView = UIView & Skrullable

public final class Skrull {
    let decorations: [Decoration]
    let skeletons: [Skeleton]
    let size: CGSize

    private(set) var insets: UIEdgeInsets = .zero
    private(set) var horizontalSpacing: CGFloat = 8.0
    private(set) var columnsCount: UInt32 = 1
    private(set) var verticalSpacing: CGFloat = 8.0
    private(set) var rowsCount: UInt32 = 1
    private(set) var fillSkeletonStartColor: UIColor?
    private(set) var fillSkeletonEndColor: UIColor?

    public init(size: CGSize, decorations: [Decorable], skeletons: [Skeletonable]) {
        self.decorations = decorations.flatMap { $0.decorations }
        self.skeletons = skeletons.flatMap { $0.skeletons }
        self.size = size
    }

    public func fillSkeletonStart(_ color: UIColor) -> Self {
        self.fillSkeletonStartColor = color

        return self
    }

    public func fillSkeletonEnd(color: UIColor) -> Self {
        self.fillSkeletonEndColor = color

        return self
    }

    public func insets(_ insets: UIEdgeInsets) -> Self {
        self.insets = insets

        return self
    }

    public func replicateHorizontally(count: UInt32, spacing: CGFloat) -> Self {
        self.columnsCount = count
        self.horizontalSpacing = spacing

        return self
    }

    public func replicateVertically(count: UInt32, spacing: CGFloat) -> Self {
        self.rowsCount = count
        self.verticalSpacing = spacing

        return self
    }

    public func build() -> SkrullableView {
        let containerSize = CGSize(width: insets.left + CGFloat(columnsCount - 1) * (size.width + horizontalSpacing) + size.width + insets.right,
                                   height: insets.top + CGFloat(rowsCount - 1) * (size.height + verticalSpacing) + size.height + insets.bottom)
        let containerFrame = CGRect(origin: .zero, size: containerSize)

        let items: [[SkrullableView]] = (0..<rowsCount).map { row in
            return (0..<columnsCount).map { column in
                let view = SkrullView(size: size,
                                      decorations: decorations,
                                      skeletons: skeletons,
                                      fillSkeletonStartColor: fillSkeletonStartColor,
                                      fillSkeletonEndColor: fillSkeletonEndColor)
                return view
            }
        }

        let containerView = SkrullContainerView(frame: containerFrame, items: items)
        containerView.insets = insets
        containerView.horizontalSpacing = horizontalSpacing
        containerView.verticalSpacing = verticalSpacing

        return containerView
    }

    public func updateSkeletons(in view: SkrullableView) {
        guard let containerView = view as? SkrullContainerView else {
            return
        }

        let allViews = containerView.items.flatMap { $0 }

        for view in allViews {
            if let view = view as? SkrullView {
                view.update(size: size, decorations: decorations, skeletons: skeletons)
            }
        }

        containerView.invalidateLayout()
    }
}
