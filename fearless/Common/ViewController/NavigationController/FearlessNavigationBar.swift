import UIKit

struct FearlessNavigationBarStyle {
    static let background: UIImage? = {
        return UIImage.background(from: UIColor.navigationBarColor)
    }()

    static let darkShadow: UIImage? = {
        return UIImage.background(from: .darkNavigationShadowColor)
    }()

    static let lightShadow: UIImage? = {
        return UIImage.background(from: .lightNavigationShadowColor)
    }()

    static let tintColor: UIColor? = {
        return UIColor.navigationBarBackTintColor
    }()

    static let titleAttributes: [NSAttributedString.Key: Any]? = {
        var titleTextAttributes = [NSAttributedString.Key: Any]()

        titleTextAttributes[.foregroundColor] = UIColor.navigationBarTitleColor

        titleTextAttributes[.font] = UIFont.navigationTitleFont

        return titleTextAttributes
    }()
}
