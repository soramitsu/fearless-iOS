import UIKit

extension UIFont {
    func dynamicSize(
        fromSize: CGFloat,
        figmaScreenHeight: CGFloat = 812
    ) -> UIFont {
        let realRatio = (UIScreen.main.bounds.size.height / figmaScreenHeight)
        let ratio = min(realRatio, 1)
        return withSize(fromSize * ratio)
    }
}
