import Foundation
import UIKit

protocol IconWithTitleViewModelFactoryProtocol {
    func crateWalletSettingsRows(for locale: Locale) -> [WalletSettingsRow]
}

enum WalletSettingsRow {
    case view(Locale)
    case export(Locale)

    var row: (icon: UIImage?, title: String) {
        switch self {
        case let .view(locale):
            return (
                icon: R.image.iconWallet(),
                title: R.string.localizable.viewWallet(preferredLanguages: locale.rLanguages)
            )
        case let .export(locale):
            return (
                icon: R.image.iconShare(),
                title: R.string.localizable.exportWallet(preferredLanguages: locale.rLanguages)
            )
        }
    }
}

final class IconWithTitleViewModelFactory: IconWithTitleViewModelFactoryProtocol {
    func crateWalletSettingsRows(for locale: Locale) -> [WalletSettingsRow] {
        [
            WalletSettingsRow.view(locale),
            WalletSettingsRow.export(locale)
        ]
    }
}
