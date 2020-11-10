import Foundation
import CommonWallet
import SoraFoundation

final class AccountShareFactory: AccountShareFactoryProtocol {
    let address: String
    let assets: [WalletAsset]
    let localizationManager: LocalizationManagerProtocol

    init(address: String, assets: [WalletAsset], localizationManager: LocalizationManagerProtocol) {
        self.assets = assets
        self.address = address
        self.localizationManager = localizationManager
    }

    func createSources(for receiveInfo: ReceiveInfo, qrImage: UIImage) -> [Any] {
        let locale = localizationManager.selectedLocale

        let asset = assets.first(where: { $0.identifier == receiveInfo.assetId }) ?? assets.first
        let symbol = asset?.symbol ?? ""
        let platform = asset?.platform?.value(for: locale) ?? ""

        let message = R.string.localizable.walletReceiveShareMessage(platform, symbol, preferredLanguages: locale.rLanguages)

        return [qrImage, message, address]
    }
}
