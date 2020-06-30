import Foundation
import CommonWallet
import SoraKeystore
import SoraFoundation

enum WalletAssetIds: String {
    case kusama
}

protocol WalletPrimitiveFactoryProtocol {
    func createAccountSettings() throws -> WalletAccountSettingsProtocol
}

enum WalletPrimitiveFactoryError: Error {
    case missingAccountId
}

final class WalletPrimitiveFactory: WalletPrimitiveFactoryProtocol {
    let keystore: KeystoreProtocol
    let settings: SettingsManagerProtocol

    init(keystore: KeystoreProtocol,
         settings: SettingsManagerProtocol) {
        self.keystore = keystore
        self.settings = settings
    }

    func createAccountSettings() throws -> WalletAccountSettingsProtocol {
        guard let accountId = settings.accountId?.toHex() else {
            throw WalletPrimitiveFactoryError.missingAccountId
        }

        let localizableName = LocalizableResource<String> { _ in "Kusama" }

        let asset = WalletAsset(identifier: WalletAssetIds.kusama.rawValue,
                                name: localizableName,
                                platform: nil,
                                symbol: "KSM",
                                precision: 18,
                                modes: [.view])

        return WalletAccountSettings(accountId: accountId, assets: [asset])
    }
}
