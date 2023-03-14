import Foundation
@testable import fearless

enum AccountGenerator {
    static func generateMetaAccount(generatingChainAccounts count: Int) -> MetaAccountModel {
        let chainAccounts = (0..<count).map { _ in generateChainAccount() }
        return generateMetaAccount(with: Set(chainAccounts))
    }

    static func generateMetaAccount(with chainAccounts: Set<ChainAccountModel> = []) -> MetaAccountModel {
        return MetaAccountModel(
            metaId: UUID().uuidString,
            name: UUID().uuidString,
            substrateAccountId: Data.random(of: 32)!,
            substrateCryptoType: 0,
            substratePublicKey: Data.random(of: 32)!,
            ethereumAddress: Data.random(of: 20)!,
            ethereumPublicKey: Data.random(of: 20)!,
            chainAccounts: chainAccounts,
            assetKeysOrder: nil,
            assetIdsEnabled: nil,
            assetFilterOptions: [],
            canExportEthereumMnemonic: true,
            unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(),
            chainIdForFilter: nil
        )
    }

    static func generateChainAccount() -> ChainAccountModel {
        ChainAccountModel(
            chainId: Data.random(of: 32)!.toHex(),
            accountId: Data.random(of: 32)!,
            publicKey: Data.random(of: 32)!,
            cryptoType: 0,
            ethereumBased: Bool.random()
        )
    }
}
