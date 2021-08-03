import UIKit

extension UIView {
    static func createSeparator(color: UIColor? = R.color.colorLightGray()) -> UIView {
        let view = UIView()
        view.backgroundColor = color
        return view
    }
}
