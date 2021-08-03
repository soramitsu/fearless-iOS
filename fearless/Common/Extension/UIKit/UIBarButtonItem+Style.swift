import Foundation
import UIKit

extension UIBarButtonItem {
    func setupDefaultTitleStyle(with font: UIFont) {
        let normalTextAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorWhite() as Any,
            .font: font
        ]

        setTitleTextAttributes(normalTextAttributes, for: .normal)

        let highlightedTextAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorGray() as Any,
            .font: font
        ]

        setTitleTextAttributes(highlightedTextAttributes, for: .highlighted)

        let disabledTextAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorDarkGray() as Any,
            .font: font
        ]

        setTitleTextAttributes(disabledTextAttributes, for: .disabled)
    }

    func setupDefaultTitleStyle() {
        setupDefaultTitleStyle(with: .h5Title)
    }
}
