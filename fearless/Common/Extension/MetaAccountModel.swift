import Foundation
import SSFModels
import UIKit

extension MetaAccountModel {
    func icon() -> UIImage {
        switch ecosystem {
        case .regular:
            return R.image.iconBirdGreen()!
        case .ton:
            return R.image.tonIcon()!
        }
    }
}
