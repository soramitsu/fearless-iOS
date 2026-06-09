/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
import UIKit

extension PlainSegmentedControl {
    @IBInspectable
    private var _titleColor: UIColor {
        set {
            titleColor = newValue
        }

        get {
            return titleColor
        }
    }

    @IBInspectable
    private var _selectedTitleColor: UIColor {
        set {
            selectedTitleColor = newValue
        }

        get {
            return selectedTitleColor
        }
    }

    @IBInspectable
    private var _titleFontName: String? {
        set {
            guard let fontName = newValue else {
                titleFont = nil
                return
            }

            guard let pointSize = titleFont?.pointSize else {
                titleFont = UIFont(name: fontName, size: UIFont.buttonFontSize)
                return
            }

            titleFont = UIFont(name: fontName, size: pointSize)
        }

        get {
            return titleFont?.fontName
        }
    }

    @IBInspectable
    private var _titleFontSize: CGFloat {
        set {
            guard let fontName = titleFont?.fontName else {
                titleFont = UIFont.systemFont(ofSize: newValue)
                return
            }

            titleFont = UIFont(name: fontName, size: newValue)
        }

        get {
            if let pointSize = titleFont?.pointSize {
                return pointSize
            } else {
                return 0.0
            }
        }
    }

    @IBInspectable
    private var _selectionColor: UIColor {
        set {
            selectionColor = newValue
        }

        get {
            return selectionColor
        }
    }

    @IBInspectable
    private var _selectionWidth: CGFloat {
        set {
            selectionWidth = newValue
        }

        get {
            return selectionWidth
        }
    }
}
