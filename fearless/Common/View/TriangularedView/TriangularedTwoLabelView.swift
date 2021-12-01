//
//  TriangularedTwoLabelView.swift
//  fearless
//
//  Created by Денис Лебедько on 29.11.2021.
//  Copyright © 2021 Soramitsu. All rights reserved.
//

import UIKit

@IBDesignable
final class TriangularedTwoLabelView: TriangularedView {
    let twoLabelView = TwoLabelView()
    var contentInsets = UIEdgeInsets(top: 8.0, left: 16, bottom: 8.0, right: 16) {
        didSet {
            invalidateLayout()
        }
    }

    override func configure() {
        super.configure()

        if twoLabelView.superview == nil {
            addSubview(twoLabelView)
        }
    }

    func invalidateLayout() {
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override var intrinsicContentSize: CGSize {
        let contentSize = twoLabelView.intrinsicContentSize

        return CGSize(
            width: contentSize.width + contentInsets.left + contentInsets.right,
            height: contentSize.height + contentInsets.top + contentInsets.bottom
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        twoLabelView.frame = CGRect(
            x: contentInsets.left,
            y: contentInsets.top,
            width: bounds.size.width - contentInsets.left - contentInsets.right,
            height: bounds.size.height - contentInsets.top - contentInsets.bottom
        )
    }
}
