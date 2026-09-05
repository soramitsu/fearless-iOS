import UIKit

extension UIFont {
    func dynamicSize(
        fromSize: CGFloat,
        figmaScreenHeight _: CGFloat = 812
    ) -> UIFont {
        // Screen dimensions must never override the user's preferred text size.
        UIFontMetrics(forTextStyle: .body).scaledFont(for: withSize(fromSize), compatibleWith: .current)
    }
}
