import Foundation
import UIKit

extension UIBarButtonItem {
    func setupDefaultTitleStyle() {
        var normalTextAttributes = [NSAttributedString.Key: Any]()
        normalTextAttributes[.foregroundColor] = R.color.colorWhite()
        normalTextAttributes[.font] = UIFont.h5Title

        setTitleTextAttributes(normalTextAttributes, for: .normal)

        var highlightedTextAttributes = [NSAttributedString.Key: Any]()
        highlightedTextAttributes[.foregroundColor] = R.color.colorGray()
        highlightedTextAttributes[.font] = UIFont.h5Title

        setTitleTextAttributes(highlightedTextAttributes, for: .highlighted)

        var disabledTextAttributes = [NSAttributedString.Key: Any]()
        disabledTextAttributes[.foregroundColor] = R.color.colorDarkGray()
        disabledTextAttributes[.font] = UIFont.h5Title

        setTitleTextAttributes(disabledTextAttributes, for: .disabled)
    }
}
