import Foundation
import UIKit

enum ChainAction {
    case export
    case switchNode

    var icon: UIImage? {
        switch self {
        case .export:
            return R.image.iconShare()
        case .switchNode:
            return R.image.iconRetry()
        }
    }

    var title: String {
        switch self {
        case .export:
            return R.string.localizable.commonExport(preferredLanguages: nil)
        case .switchNode:
            return R.string.localizable.switchNode(preferredLanguages: nil)
        }
    }
}
