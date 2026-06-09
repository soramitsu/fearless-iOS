/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

/**
    Subclass of ShadowShapeView designed to provided view with rounded corners.
 */

open class RoundedView: ShadowShapeView {
    /// Defaults `8.0`
    @IBInspectable
    open var cornerRadius: CGFloat = 8.0 {
        didSet {
            applyPath()
        }
    }

    /// Defaults `.allCorners`
    open var roundingCorners: UIRectCorner = UIRectCorner.allCorners {
        didSet {
            applyPath()
        }
    }

    // MARK: Overriden methods
    override open var shapePath: UIBezierPath {
        return UIBezierPath(roundedRect: self.bounds, byRoundingCorners: roundingCorners,
                            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
    }
}

/// Extension of RoundedView to support corners customization via Interface Builder
extension RoundedView {
    @IBInspectable
    private var _topLeftRounded: Bool {
        get {
            return self.roundingCorners.contains(UIRectCorner.topLeft)
        }

        set(newValue) {
            if newValue {
                self.roundingCorners.insert(UIRectCorner.topLeft)
            } else {
                self.roundingCorners.remove(UIRectCorner.topLeft)
            }

        }
    }

    @IBInspectable
    private var _topRightRounded: Bool {
        get {
            return self.roundingCorners.contains(UIRectCorner.topRight)
        }

        set(newValue) {
            if newValue {
                self.roundingCorners.insert(UIRectCorner.topRight)
            } else {
                self.roundingCorners.remove(UIRectCorner.topRight)
            }
        }
    }

    @IBInspectable
    private var _bottomLeftRounded: Bool {
        get {
            return self.roundingCorners.contains(UIRectCorner.bottomLeft)
        }

        set(newValue) {
            if newValue {
                self.roundingCorners.insert(UIRectCorner.bottomLeft)
            } else {
                self.roundingCorners.remove(UIRectCorner.bottomLeft)
            }

        }
    }

    @IBInspectable
    private var _bottomRightRounded: Bool {
        get {
            return self.roundingCorners.contains(UIRectCorner.bottomRight)
        }

        set(newValue) {
            if newValue {
                self.roundingCorners.insert(UIRectCorner.bottomRight)
            } else {
                self.roundingCorners.remove(UIRectCorner.bottomRight)
            }

        }
    }
}
