import UIKit

struct FearlessNavigationBarStyle {
    static let background: UIImage? = {
        return UIImage.background(from: UIColor.navigationBarColor)
    }()

    static let darkShadow: UIImage? = {
        let color = UIColor(white: 153.0 / 255.0, alpha: 0.25)
        return UIImage.background(from: color)
    }()

    static let lightShadow: UIImage? = {
        let color = UIColor(red: 198.0 / 255.0, green: 231.0 / 255.0, blue: 224.0 / 255.0, alpha: 1.0)
        return UIImage.background(from: color)
    }()

    static let tintColor: UIColor? = {
        return UIColor.navigationBarBackTintColor
    }()

    static let titleAttributes: [NSAttributedString.Key: Any]? = {
        var titleTextAttributes = [NSAttributedString.Key: Any]()

        titleTextAttributes[.foregroundColor] = UIColor(red: 0.0 / 255.0,
                                                        green: 0.0 / 255.0,
                                                        blue: 0.0 / 255.0,
                                                        alpha: 1.0)

        titleTextAttributes[.font] = R.font.soraRc0040417Bold(size: 15)!

        return titleTextAttributes
    }()
}
