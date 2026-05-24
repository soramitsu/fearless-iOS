import UIKit
import Foundation

@IBDesignable
extension BaseActionControl {
    @IBInspectable
    private var _topInset: CGFloat {
        set(newValue) {
            let insets = self.contentInsets
            self.contentInsets = UIEdgeInsets(top: newValue,
                                              left: insets.left,
                                              bottom: insets.bottom,
                                              right: insets.right)
        }

        get {
            return self.contentInsets.top
        }
    }

    @IBInspectable
    private var _leftInset: CGFloat {
        set(newValue) {
            let insets = self.contentInsets
            self.contentInsets = UIEdgeInsets(top: insets.top,
                                              left: newValue,
                                              bottom: insets.bottom,
                                              right: insets.right)
        }

        get {
            return self.contentInsets.top
        }
    }

    @IBInspectable
    private var _bottomInset: CGFloat {
        set(newValue) {
            let insets = self.contentInsets
            self.contentInsets = UIEdgeInsets(top: insets.top,
                                              left: insets.left,
                                              bottom: newValue,
                                              right: insets.right)
        }

        get {
            return self.contentInsets.top
        }
    }

    @IBInspectable
    private var _rightInset: CGFloat {
        set(newValue) {
            let insets = self.contentInsets
            self.contentInsets = UIEdgeInsets(top: insets.top,
                                              left: insets.left,
                                              bottom: insets.bottom,
                                              right: newValue)
        }

        get {
            return self.contentInsets.top
        }
    }
}
