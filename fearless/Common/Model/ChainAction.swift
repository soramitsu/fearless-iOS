import Foundation
import UIKit

enum ChainAction {
    case copyAddress
    case polkascan(url: URL)
    case subscan(url: URL)
    case switchNode
    case export

    var icon: UIImage? {
        switch self {
        case .export:
            return R.image.iconShare()
        case .switchNode:
            return R.image.iconRetry()
        case .copyAddress:
            return R.image.iconCopy()
        case .polkascan, .subscan:
            return R.image.iconOpenWeb()
        }
    }

    var title: String {
        switch self {
        case .export:
            return R.string.localizable.commonExport(preferredLanguages: nil)
        case .switchNode:
            return R.string.localizable.switchNode(preferredLanguages: nil)
        case .copyAddress:
            return R.string.localizable.commonCopyAddress(preferredLanguages: nil)
        case .polkascan:
            return R.string.localizable
                .transactionDetailsViewPolkascan(preferredLanguages: nil)
        case .subscan:
            return R.string.localizable
                .transactionDetailsViewSubscan(preferredLanguages: nil)
        }
    }
}
