/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

@IBDesignable
open class SliderView: UISlider {
    @IBInspectable
    open var trackHeight: CGFloat = 2.0 {
        didSet {
            setNeedsDisplay()
        }
    }

    @IBInspectable
    open var normalThumbImage: UIImage? {
        set(newValue) {
            setThumbImage(newValue, for: .normal)
        }

        get {
            return thumbImage(for: .normal)
        }
    }

    override open func trackRect(forBounds bounds: CGRect) -> CGRect {
        var result = super.trackRect(forBounds: bounds)
        let height = min(trackHeight, bounds.height)
        result.origin.y = bounds.midY - height / 2.0
        result.size.height = height
        return result
    }
}
