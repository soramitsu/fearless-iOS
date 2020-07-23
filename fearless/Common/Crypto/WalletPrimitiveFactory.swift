import Foundation
import CommonWallet
import SoraKeystore
import SoraFoundation
import IrohaCrypto

enum WalletAssetIds: String {
    case kusama
    case westend
    case dot
    case generic
}

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

        guard let selectedConnectionType = SNAddressType(rawValue: settings.selectedConnection.type) else {
            throw WalletPrimitiveFactoryError.undefinedConnection
        }

        let localizableName: LocalizableResource<String>
        let platformName: LocalizableResource<String>
        let symbol: String
        let identifier: String

        switch selectedConnectionType {
        case .polkadotMain:
            identifier = WalletAssetIds.dot.rawValue
            localizableName = LocalizableResource<String> { _ in "DOT" }
            platformName = LocalizableResource<String> { _ in "Polkadot" }
            symbol = "DOT"
        case .kusamaMain:
            identifier = WalletAssetIds.kusama.rawValue
            localizableName = LocalizableResource<String> { _ in "KSM" }
            platformName = LocalizableResource<String> { _ in "Kusama" }
            symbol = "KSM"
        case .genericSubstrate:
            identifier = WalletAssetIds.westend.rawValue
            localizableName = LocalizableResource<String> { _ in "WND" }
            platformName = LocalizableResource<String> { _ in "Westend" }
            symbol = "WND"
        default:
            identifier = WalletAssetIds.generic.rawValue
            localizableName = LocalizableResource<String> { _ in "DOT" }
            platformName = LocalizableResource<String> { _ in "Substrate Generic" }
            symbol = "DOT"
        }

        let asset = WalletAsset(identifier: identifier,
                                name: localizableName,
                                platform: platformName,
                                symbol: symbol,
                                precision: 12,
                                modes: .all)

        let publicKey = try SS58AddressFactory().publicKey(fromAddress: selectedAccount.address,
                                                           type: selectedConnectionType)

        return WalletAccountSettings(accountId: publicKey.rawData().toHex(), assets: [asset])
    }
}
