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
            twoLabelView.titleLabel.text
        }

        set {
            twoLabelView.titleLabel.text = newValue
        }
    }

    @IBInspectable
    private var _titleColor: UIColor? {
        get {
            twoLabelView.titleLabel.textColor
        }

        set {
            twoLabelView.titleLabel.textColor = newValue
        }
    }

    @IBInspectable
    private var _titleFontName: String? {
        get {
            twoLabelView.titleLabel.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                twoLabelView.titleLabel.font = nil
                return
            }

            guard let pointSize = twoLabelView.titleLabel.font?.pointSize else {
                twoLabelView.titleLabel.font = UIFont(name: fontName, size: UIFont.buttonFontSize)
                return
            }

            twoLabelView.titleLabel.font = UIFont(name: fontName, size: pointSize)

            invalidateLayout()
        }
    }

    @IBInspectable
    private var _titleFontSize: CGFloat {
        get {
            if let pointSize = twoLabelView.titleLabel.font?.pointSize {
                return pointSize
            } else {
                return 0.0
            }
        }

        set(newValue) {
            guard let fontName = twoLabelView.titleLabel.font?.fontName else {
                twoLabelView.titleLabel.font = UIFont.systemFont(ofSize: newValue)
                return
            }

            twoLabelView.titleLabel.font = UIFont(name: fontName, size: newValue)

            invalidateLayout()
        }
    }

    @IBInspectable
    private var _subtitle: String? {
        get {
            twoLabelView.subtitleLabelView.text
        }

        set {
            twoLabelView.subtitleLabelView.text = newValue
        }
    }

    @IBInspectable
    private var _subtitleColor: UIColor? {
        get {
            twoLabelView.subtitleLabelView.textColor
        }

        set {
            twoLabelView.subtitleLabelView.textColor = newValue
        }
    }

    @IBInspectable
    private var _subtitleFontName: String? {
        get {
            twoLabelView.subtitleLabelView.font?.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                twoLabelView.subtitleLabelView.font = nil
                return
            }

            guard let pointSize = twoLabelView.subtitleLabelView.font?.pointSize else {
                twoLabelView.subtitleLabelView.font = UIFont(
                    name: fontName,
                    size: UIFont.buttonFontSize
                )
                return
            }

            twoLabelView.subtitleLabelView.font = UIFont(name: fontName, size: pointSize)

            invalidateLayout()
        }
    }

    @IBInspectable
    private var _subtitleFontSize: CGFloat {
        get {
            if let pointSize = twoLabelView.subtitleLabelView.font?.pointSize {
                return pointSize
            } else {
                return 0.0
            }
        }

        set(newValue) {
            guard let fontName = twoLabelView.subtitleLabelView.font?.fontName else {
                twoLabelView.subtitleLabelView.font = UIFont.systemFont(ofSize: newValue)
                return
            }

            twoLabelView.subtitleLabelView.font = UIFont(name: fontName, size: newValue)

            invalidateLayout()
        }
    }
}
