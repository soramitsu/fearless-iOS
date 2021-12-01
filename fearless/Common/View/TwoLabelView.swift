//
//  TriangularedTwoLabelView.swift
//  fearless
//
//  Created by Денис Лебедько on 29.11.2021.
//  Copyright © 2021 Soramitsu. All rights reserved.
//

import UIKit

class TwoLabelView: UIView {
    let titleLabel = UILabel()
    let subtitleLabelView = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
    }

    private func configure() {
        if titleLabel.superview == nil {
            addSubview(titleLabel)
        }

        if subtitleLabelView.superview == nil {
            addSubview(subtitleLabelView)
        }
    }

    var verticalSpacing: CGFloat = 3.0 {
        didSet {
            invalidateLayout()
        }
    }

    var horizontalSubtitleSpacing: CGFloat = 8.0 {
        didSet {
            invalidateLayout()
        }
    }

    func invalidateLayout() {
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    // MARK: Overriding

    override var intrinsicContentSize: CGSize {
        let titleSize = titleLabel.intrinsicContentSize
        let subtitleSize = subtitleLabelView.intrinsicContentSize

        let width = max(titleSize.width, subtitleSize.width)
        let height = titleSize.height + verticalSpacing + subtitleSize.height

        return CGSize(width: width, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        titleLabel.frame = CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: min(titleLabel.intrinsicContentSize.width, bounds.width),
            height: titleLabel.intrinsicContentSize.height
        )

        subtitleLabelView.frame = CGRect(
            x: bounds.minX,
            y: titleLabel.frame.maxY + verticalSpacing,
            width: bounds.size.width,
            height: subtitleLabelView.intrinsicContentSize.height
        )
    }
}
