import Foundation
import SoraFoundation
import SoraKeystore

protocol AccountShareFactoryProtocol {
    func createSources(
        accountAddress: String,
        qrImage: UIImage,
        assetSymbol: String,
        chainName: String,
        locale: Locale
    ) -> [Any]
}

final class AccountShareFactory: AccountShareFactoryProtocol {
    func createSources(
        accountAddress: String,
        qrImage: UIImage,
        assetSymbol: String,
        chainName: String,
        locale: Locale
    ) -> [Any] {
        let message = R.string.localizable
            .walletReceiveShareMessage(chainName, assetSymbol, preferredLanguages: locale.rLanguages)
        return [qrImage, message, accountAddress]
    }
}
