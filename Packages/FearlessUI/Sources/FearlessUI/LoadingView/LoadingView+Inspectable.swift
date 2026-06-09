/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

@IBDesignable
extension LoadingView {

    @IBInspectable
    private var _indicatorImage: UIImage? {
        set(newValue) {
            indicatorImage = newValue
        }

        get {
            return indicatorImage
        }
    }

    @IBInspectable
    private var _contentBackgroundColor: UIColor {
        set(newValue) {
            contentBackgroundColor = newValue
        }

        get {
            return contentBackgroundColor
        }
    }

    @IBInspectable
    private var _contentCornerRadius: CGFloat {
        set(newValue) {
            contentCornerRadius = newValue
        }

        get {
            return contentCornerRadius
        }
    }

    @IBInspectable
    private var _contentSize: CGSize {
        set(newValue) {
            contentSize = newValue
        }

        get {
            return contentSize
        }
    }
}
