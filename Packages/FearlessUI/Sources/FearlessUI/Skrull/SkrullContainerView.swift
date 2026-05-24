import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

final class SkrullContainerView: UIView {
    let items: [[SkrullableView]]

    var insets: UIEdgeInsets = .zero {
        didSet {
            setNeedsLayout()
        }
    }

    var horizontalSpacing: CGFloat = 8.0 {
        didSet {
            setNeedsLayout()
        }
    }

    var verticalSpacing: CGFloat = 8.0 {
        didSet {
            setNeedsLayout()
        }
    }

    init(frame: CGRect, items: [[SkrullableView]]) {
        self.items = items

        super.init(frame: frame)

        items.flatMap({ $0 }).forEach { addSubview($0) }
    }

    func invalidateLayout() {
        performLayout()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        performLayout()
    }

    private func performLayout() {
        for (row, colums) in items.enumerated() {
            for (column, item) in colums.enumerated() {
                layout(item: item, row: row, column: column)
            }
        }
    }

    private func layout(item: SkrullableView, row: Int, column: Int) {
        item.frame = CGRect(x: insets.left + CGFloat(column) * (item.frame.size.width + horizontalSpacing),
                            y: insets.top + CGFloat(row) * (item.frame.size.height + verticalSpacing),
                            width: item.frame.size.width,
                            height: item.frame.size.height)
    }
}

extension SkrullContainerView: Skrullable {
    func startSkrulling() {
        items.flatMap({ $0 }).forEach { $0.startSkrulling() }
    }

    func stopSkrulling() {
        items.flatMap({ $0 }).forEach { $0.stopSkrulling() }
    }
}
