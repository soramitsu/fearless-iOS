import Foundation
import UIKit

enum ChainAction {
    case copyAddress
    case polkascan(url: URL)
    case subscan(url: URL)
    case etherscan(url: URL)
    case switchNode
    case export
    case replace

    var icon: UIImage? {
        switch self {
        case .export:
            return R.image.iconShare()
        case .switchNode:
            return R.image.iconRetry()
        case .copyAddress:
            return R.image.iconCopy()
        case .polkascan, .subscan, .etherscan:
            return R.image.iconOpenWeb()
        case .replace:
            return R.image.iconReplace()
        }
    }

    func localizableTitle(for locale: Locale) -> String {
        switch self {
        case .export:
            return R.string.localizable.commonExport(preferredLanguages: locale.rLanguages)
        case .switchNode:
            return R.string.localizable.switchNode(preferredLanguages: locale.rLanguages)
        case .copyAddress:
            return R.string.localizable.commonCopyAddress(preferredLanguages: locale.rLanguages)
        case .polkascan:
            return R.string.localizable
                .transactionDetailsViewPolkascan(preferredLanguages: locale.rLanguages)
        case .subscan:
            return R.string.localizable
                .transactionDetailsViewSubscan(preferredLanguages: locale.rLanguages)
        case .replace:
            return R.string.localizable.replaceAccount(preferredLanguages: locale.rLanguages)
        case .etherscan:
            return R.string.localizable.transactionDetailsViewEtherscan(preferredLanguages: locale.rLanguages)
        }
    }
}
