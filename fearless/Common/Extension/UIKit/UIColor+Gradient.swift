import Foundation
import UIKit

extension UIColor {
    static var walletBorderGradientColors: [UIColor] {
        [
            R.color.walletGradientColor0(),
            R.color.walletGradientColor1(),
            R.color.walletGradientColor2(),
            R.color.walletGradientColor3()
        ].compactMap { $0 }
    }
}
