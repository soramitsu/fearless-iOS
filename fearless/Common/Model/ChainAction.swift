import Foundation
import UIKit

enum ChainAction {
    case copyAddress
    case polkascan(url: URL)
    case subscan(url: URL)
    case etherscan(url: URL)
    case oklink(url: URL)
    case switchNode
    case export
    case replace
    case reefscan(url: URL)
    case claimCrowdloanRewards
    /// Use a per-chain account the wallet keeps stored but does not use on this chain.
    case useStoredAccount(address: String)
    /// Go back from a per-chain account to the wallet's own account on this chain.
    case useWalletAccount
    /// Replace the account the words alone open with the one the wallet password protects.
    case switchToPasswordAccount

    var icon: UIImage? {
        switch self {
        case .export:
            return R.image.iconShare()
        case .switchNode:
            return R.image.iconRetry()
        case .copyAddress:
            return R.image.iconCopy()
        case .polkascan, .subscan, .etherscan, .reefscan, .oklink:
            return R.image.iconOpenWeb()
        case .replace, .useStoredAccount, .useWalletAccount, .switchToPasswordAccount:
            return R.image.iconReplace()
        case .claimCrowdloanRewards:
            return R.image.iconInfo()
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
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
        case .reefscan:
            return R.string.localizable.transactionDetailsViewReefscan(preferredLanguages: locale.rLanguages)
        case .claimCrowdloanRewards:
            return NSLocalizedString(
                "asset.legacy_crowdloan",
                value: "Legacy crowdloan",
                comment: "Contextual recovery action for a historical crowdloan lock"
            )
        case .oklink:
            return R.string.localizable.transactionDetailsViewOklink(preferredLanguages: locale.rLanguages)
        case let .useStoredAccount(address):
            return R.string.localizable.walletChainAccountsUseStored(
                Self.shortened(address),
                preferredLanguages: locale.rLanguages
            )
        case .useWalletAccount:
            return R.string.localizable.walletChainAccountsUseWallet(preferredLanguages: locale.rLanguages)
        case .switchToPasswordAccount:
            return R.string.localizable.universalPasswordChainAction(preferredLanguages: locale.rLanguages)
        }
    }

    /// Enough of both ends to tell two accounts apart in a one-line menu row.
    static func shortened(_ address: String) -> String {
        let visibleCharacters = 8
        guard address.count > visibleCharacters * 2 + 1 else {
            return address
        }

        return "\(address.prefix(visibleCharacters))…\(address.suffix(visibleCharacters))"
    }
}
