import UIKit

struct FearlessNavigationBarStyle {
    static let background: UIImage? = {
        return UIImage.background(from: R.color.colorAlmostBlack()!)
    }()

    static let darkShadow: UIImage? = {
        return UIImage.background(from: R.color.colorDarkGray()!)
    }()

    static let lightShadow: UIImage? = {
        return UIImage.background(from: R.color.colorLightGray()!)
    }()

    static let tintColor: UIColor? = {
        return R.color.colorWhite()!
    }()

    static let titleAttributes: [NSAttributedString.Key: Any]? = {
        var titleTextAttributes = [NSAttributedString.Key: Any]()

        titleTextAttributes[.foregroundColor] = R.color.colorWhite()!

        titleTextAttributes[.font] = UIFont.h3Title

        return titleTextAttributes
    }()
}
