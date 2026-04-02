import Foundation
@testable import fearless
import SSFModels

enum AccountGenerator {
    static func generateMetaAccount(generatingChainAccounts count: Int) -> fearless.MetaAccountModel {
        let chainAccounts = (0..<count).map { _ in generateChainAccount() }
        return generateMetaAccount(with: Set(chainAccounts))
    }

    static func generateMetaAccount(with chainAccounts: Set<ChainAccountModel> = []) -> fearless.MetaAccountModel {
        fearless.MetaAccountModel(
            metaId: UUID().uuidString,
            name: UUID().uuidString,
            substrateAccountId: Data.random(of: 32)!,
            substrateCryptoType: 0,
            substratePublicKey: Data.random(of: 32)!,
            ethereumAddress: Data.random(of: 20)!,
            ethereumPublicKey: Data.random(of: 20)!,
            chainAccounts: chainAccounts,
            assetKeysOrder: nil,
            canExportEthereumMnemonic: true,
            unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(),
            networkManagmentFilter: nil,
            assetsVisibility: [],
            hasBackup: true,
            favouriteChainIds: []
        )
    }

    static func generateChainAccount() -> ChainAccountModel {
        let isEthereum = Bool.random()
        return SSFModels.ChainAccountModel(
            chainId: Data.random(of: 32)!.toHex(),
            accountId: Data.random(of: 32)!,
            publicKey: Data.random(of: 32)!,
            cryptoType: 0,
            ecosystem: isEthereum ? .ethereum : .substrate
        )
    }
}
