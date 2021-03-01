import Foundation
import UIKit

extension UIBarButtonItem {
    func setupDefaultTitleStyle() {
        let normalTextAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorWhite() as Any,
            .font: UIFont.h5Title
        ]

        setTitleTextAttributes(normalTextAttributes, for: .normal)

        let highlightedTextAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorGray() as Any,
            .font: UIFont.h5Title
        ]

        setTitleTextAttributes(highlightedTextAttributes, for: .highlighted)

        let disabledTextAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorDarkGray() as Any,
            .font: UIFont.h5Title
        ]

        setTitleTextAttributes(disabledTextAttributes, for: .disabled)
    }
}
