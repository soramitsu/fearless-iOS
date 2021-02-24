import Foundation
import CommonWallet
import SoraKeystore
import SoraFoundation
import IrohaCrypto

protocol WalletPrimitiveFactoryProtocol {
    func createAssetForAddressType(_ addressType: SNAddressType) -> WalletAsset
    func createPriceAsset() -> WalletAsset
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

    func createAssetForAddressType(_ addressType: SNAddressType) -> WalletAsset {
        let localizableName: LocalizableResource<String>
        let platformName: LocalizableResource<String>
        let symbol: String
        let identifier: String

        switch addressType {
        case .polkadotMain:
            identifier = WalletAssetId.dot.rawValue
            localizableName = LocalizableResource<String> { _ in "DOT" }
            platformName = LocalizableResource<String> { _ in "Polkadot" }
            symbol = "DOT"
        case .genericSubstrate:
            identifier = WalletAssetId.westend.rawValue
            localizableName = LocalizableResource<String> { _ in "Westend" }
            platformName = LocalizableResource<String> { _ in "Westend" }
            symbol = "WND"
        default:
            identifier = WalletAssetId.kusama.rawValue
            localizableName = LocalizableResource<String> { _ in "Kusama" }
            platformName = LocalizableResource<String> { _ in "Kusama" }
            symbol = "KSM"
        }

        return WalletAsset(identifier: identifier,
                           name: localizableName,
                           platform: platformName,
                           symbol: symbol,
                           precision: addressType.precision,
                           modes: .all)
    }

    func createPriceAsset() -> WalletAsset {
        WalletAsset(identifier: WalletAssetId.usd.rawValue,
                    name: LocalizableResource { _ in "" },
                    platform: LocalizableResource { _ in "" },
                    symbol: "$",
                    precision: 2,
                    modes: .view)
    }

    func createAccountSettings() throws -> WalletAccountSettingsProtocol {
        guard let selectedAccount = settings.selectedAccount else {
            throw WalletPrimitiveFactoryError.missingAccountId
        }

        let selectedConnectionType = settings.selectedConnection.type

        let networkAsset = createAssetForAddressType(selectedConnectionType)

        let totalPriceAsset = createPriceAsset()

        let accountId = try SS58AddressFactory().accountId(fromAddress: selectedAccount.address,
                                                           type: settings.selectedConnection.type)

        return WalletAccountSettings(accountId: accountId.toHex(),
                                     assets: [totalPriceAsset, networkAsset])
    }
}
