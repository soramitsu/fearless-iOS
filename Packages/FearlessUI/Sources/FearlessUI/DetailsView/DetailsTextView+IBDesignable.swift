import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

extension DetailsTextView {
    @IBInspectable
    private var _textFontName: String {
        set(newValue) {
            if let font = UIFont(name: newValue, size: self.textFont.pointSize) {
                textFont = font
            }
        }

        get {
            return textFont.fontName
        }
    }

    @IBInspectable
    private var _textFontSize: CGFloat {
        set(newValue) {
            if let font = UIFont(name: self.textFont.fontName, size: newValue) {
                textFont = font
            }
        }

        get {
            return textFont.pointSize
        }
    }
}
