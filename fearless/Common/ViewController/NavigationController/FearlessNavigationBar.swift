import UIKit

struct FearlessNavigationBarStyle {
    static let background: UIImage? = {
        UIImage.background(from: R.color.colorBlack()!)
    }()

    static let darkShadow: UIImage? = {
        UIImage.background(from: R.color.colorDarkGray()!)
    }()

    static let lightShadow: UIImage? = {
        UIImage.background(from: R.color.colorLightGray()!)
    }()

    static let tintColor: UIColor? = {
        R.color.colorWhite()!
    }()

    static let titleAttributes: [NSAttributedString.Key: Any]? = {
        var titleTextAttributes = [NSAttributedString.Key: Any]()

        titleTextAttributes[.foregroundColor] = R.color.colorWhite()!

        titleTextAttributes[.font] = UIFont.h3Title

        return titleTextAttributes
    }()
}
