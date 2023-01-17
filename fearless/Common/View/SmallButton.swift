import UIKit

class SmallButton: UIButton {
    private enum Constants {
        static let touchAreaIncreaseValue: CGFloat = 10
    }

    override func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        bounds.insetBy(
            dx: -Constants.touchAreaIncreaseValue,
            dy: -Constants.touchAreaIncreaseValue
        ).contains(point)
    }
}
