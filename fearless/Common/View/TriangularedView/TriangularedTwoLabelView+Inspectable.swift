//
//  TriangularedTwoLabelView+Inspectable.swift
//  fearless
//
//  Created by Денис Лебедько on 29.11.2021.
//  Copyright © 2021 Soramitsu. All rights reserved.
//

import UIKit

extension TriangularedTwoLabelView {
    @IBInspectable
    private var _title: String? {
        get {
            twoVerticalLabelView.titleLabel.text
        }

        set {
            twoVerticalLabelView.titleLabel.text = newValue
        }
    }

    @IBInspectable
    private var _titleColor: UIColor? {
        get {
            twoVerticalLabelView.titleLabel.textColor
        }

        set {
            twoVerticalLabelView.titleLabel.textColor = newValue
        }
    }

    @IBInspectable
    private var _titleFontName: String? {
        get {
            twoVerticalLabelView.titleLabel.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                twoVerticalLabelView.titleLabel.font = nil
                return
            }

            guard let pointSize = twoVerticalLabelView.titleLabel.font?.pointSize else {
                twoVerticalLabelView.titleLabel.font = UIFont(name: fontName, size: UIFont.buttonFontSize)
                return
            }

            twoVerticalLabelView.titleLabel.font = UIFont(name: fontName, size: pointSize)

            invalidateLayout()
        }
    }

    @IBInspectable
    private var _titleFontSize: CGFloat {
        get {
            if let pointSize = twoVerticalLabelView.titleLabel.font?.pointSize {
                return pointSize
            } else {
                return 0.0
            }
        }

        set(newValue) {
            guard let fontName = twoVerticalLabelView.titleLabel.font?.fontName else {
                twoVerticalLabelView.titleLabel.font = UIFont.systemFont(ofSize: newValue)
                return
            }

            twoVerticalLabelView.titleLabel.font = UIFont(name: fontName, size: newValue)

            invalidateLayout()
        }
    }

    @IBInspectable
    private var _subtitle: String? {
        get {
            twoVerticalLabelView.subtitleLabelView.text
        }

        set {
            twoVerticalLabelView.subtitleLabelView.text = newValue
        }
    }

    @IBInspectable
    private var _subtitleColor: UIColor? {
        get {
            twoVerticalLabelView.subtitleLabelView.textColor
        }

        set {
            twoVerticalLabelView.subtitleLabelView.textColor = newValue
        }
    }

    @IBInspectable
    private var _subtitleFontName: String? {
        get {
            twoVerticalLabelView.subtitleLabelView.font?.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                twoVerticalLabelView.subtitleLabelView.font = nil
                return
            }

            guard let pointSize = twoVerticalLabelView.subtitleLabelView.font?.pointSize else {
                twoVerticalLabelView.subtitleLabelView.font = UIFont(
                    name: fontName,
                    size: UIFont.buttonFontSize
                )
                return
            }

            twoVerticalLabelView.subtitleLabelView.font = UIFont(name: fontName, size: pointSize)

            invalidateLayout()
        }
    }

    @IBInspectable
    private var _subtitleFontSize: CGFloat {
        get {
            if let pointSize = twoVerticalLabelView.subtitleLabelView.font?.pointSize {
                return pointSize
            } else {
                return 0.0
            }
        }

        set(newValue) {
            guard let fontName = twoVerticalLabelView.subtitleLabelView.font?.fontName else {
                twoVerticalLabelView.subtitleLabelView.font = UIFont.systemFont(ofSize: newValue)
                return
            }

            twoVerticalLabelView.subtitleLabelView.font = UIFont(name: fontName, size: newValue)

            invalidateLayout()
        }
    }
}
