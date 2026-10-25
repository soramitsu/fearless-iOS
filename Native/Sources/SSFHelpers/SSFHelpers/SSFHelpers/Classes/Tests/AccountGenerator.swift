import Foundation
import SSFModels

public enum AccountGenerator {
    public static func generateMetaAccount(generatingChainAccounts count: Int) -> MetaAccountModel {
        let chainAccounts = (0 ..< count).map { _ in generateChainAccount() }
        return generateMetaAccount(with: Set(chainAccounts))
    }

    public static func generateMetaAccount(with chainAccounts: Set<ChainAccountModel> = [])
        -> MetaAccountModel
    {
        MetaAccountModel(
            metaId: UUID().uuidString,
            name: UUID().uuidString,
            substrateAccountId: Data.random(of: 32)!,
            substrateCryptoType: 0,
            substratePublicKey: Data.random(of: 32)!,
            ethereumAddress: Data.random(of: 20)!,
            ethereumPublicKey: Data.random(of: 20)!,
            chainAccounts: chainAccounts,
            assetKeysOrder: nil,
            assetFilterOptions: [],
            canExportEthereumMnemonic: true,
            unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(),
            networkManagmentFilter: nil,
            assetsVisibility: [],
            zeroBalanceAssetsHidden: true,
            hasBackup: false,
            favouriteChainIds: []
        )
    }

    public static func generateChainAccount() -> ChainAccountModel {
        ChainAccountModel(
            chainId: Data.random(of: 32)!.toHex(),
            accountId: Data.random(of: 32)!,
            publicKey: Data.random(of: 32)!,
            cryptoType: 0,
            ethereumBased: Bool.random()
        )
    }
}
