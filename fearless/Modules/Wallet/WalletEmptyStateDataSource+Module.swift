import Foundation
import SoraFoundation

extension WalletEmptyStateDataSource {
    static var history: WalletEmptyStateDataSource {
        let title = LocalizableResource { locale in
            R.string.localizable.walletEmptyDescription(preferredLanguages: locale.rLanguages)
        }

        let image = R.image.iconAbout()?
            .tinted(with: UIColor.iconTintColor)?
            .withRenderingMode(.alwaysOriginal)
        let dataSource = WalletEmptyStateDataSource(titleResource: title, image: image)
        dataSource.localizationManager = LocalizationManager.shared

        return dataSource
    }
}
