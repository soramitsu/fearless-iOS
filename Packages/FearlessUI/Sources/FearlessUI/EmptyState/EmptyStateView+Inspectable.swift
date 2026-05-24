/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

public extension EmptyStateView {
    @IBInspectable
    private var _titleFontName: String {
        get {
            return titleFont.fontName
        }

        set {
            if let newFont = UIFont(name: newValue, size: titleFont.pointSize) {
                titleFont = newFont
            } else {
                titleFont = UIFont.systemFont(ofSize: titleFont.pointSize)
            }
        }
    }

    @IBInspectable
    private var _titleFontSize: CGFloat {
        get {
            return titleFont.pointSize
        }

        set {
            if let newFont = UIFont(name: titleFont.fontName, size: newValue) {
                titleFont = newFont
            } else {
                titleFont = UIFont.systemFont(ofSize: titleFont.pointSize)
            }
        }
    }
}
