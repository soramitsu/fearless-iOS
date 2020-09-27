import Foundation
import CommonWallet
import SoraKeystore
import SoraFoundation
import IrohaCrypto

protocol WalletPrimitiveFactoryProtocol {
    func createAccountSettings() throws -> WalletAccountSettingsProtocol
}

enum WalletPrimitiveFactoryError: Error {
    case missingAccountId
    case undefinedConnection
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
        guard let selectedAccount = settings.selectedAccount else {
            throw WalletPrimitiveFactoryError.missingAccountId
        }

        let selectedConnectionType = settings.selectedConnection.type

        let localizableName: LocalizableResource<String>
        let platformName: LocalizableResource<String>
        let symbol: String
        let identifier: String
        let precision: Int16

        switch selectedConnectionType {
        case .polkadotMain:
            identifier = WalletAssetId.dot.rawValue
            localizableName = LocalizableResource<String> { _ in "DOT" }
            platformName = LocalizableResource<String> { _ in "Polkadot" }
            symbol = "DOT"
            precision = 10
        case .genericSubstrate:
            identifier = WalletAssetId.westend.rawValue
            localizableName = LocalizableResource<String> { _ in "Westend" }
            platformName = LocalizableResource<String> { _ in "Westend" }
            symbol = "WND"
            precision = 12
        default:
            identifier = WalletAssetId.kusama.rawValue
            localizableName = LocalizableResource<String> { _ in "Kusama" }
            platformName = LocalizableResource<String> { _ in "Kusama" }
            symbol = "KSM"
            precision = 12
        }

        let asset = WalletAsset(identifier: identifier,
                                name: localizableName,
                                platform: platformName,
                                symbol: symbol,
                                precision: precision,
                                modes: .all)

        return WalletAccountSettings(accountId: selectedAccount.publicKeyData.toHex(), assets: [asset])
    }
}
