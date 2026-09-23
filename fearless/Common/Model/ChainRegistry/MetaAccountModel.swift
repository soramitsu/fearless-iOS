import Foundation
import RobinHood
import SSFModels

typealias MetaAccountId = String

struct MetaAccountModel: Equatable, Codable {
    let metaId: MetaAccountId
    let name: String
    let substrateAccountId: Data?
    let substrateCryptoType: UInt8
    let substratePublicKey: Data?
    let ethereumAddress: Data?
    let ethereumPublicKey: Data?
    let chainAccounts: Set<ChainAccountModel>
    let assetKeysOrder: [String]?
    let canExportEthereumMnemonic: Bool
    let unusedChainIds: [String]?
    let selectedCurrency: Currency
    let networkManagmentFilter: String?
    let assetsVisibility: [AssetVisibility]
    let hasBackup: Bool
    let favouriteChainIds: [ChainModel.Id]

    var legacyTonAccount: LegacyTonAccount? = nil

    var backupAddress: String {
        if let legacyTonAccount, substratePublicKey == nil {
            return legacyTonAccount.address
        }
        if substratePublicKey == nil, let ethereumAddress {
            return (try? ethereumAddress.toAddress(using: .ethereum)) ?? ethereumAddress.toHex()
        }
        return substratePublicKey.flatMap { try? $0.toAddress(using: .substrate(42)) } ?? substratePublicKey?.toHex() ?? metaId
    }

    var utilsModel: SSFModels.MetaAccountModel? {
        guard let substrateAccountId, let substratePublicKey else { return nil }
        return SSFModels.MetaAccountModel(
            metaId: metaId,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: chainAccounts,
            assetKeysOrder: assetKeysOrder,
            assetFilterOptions: [],
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            zeroBalanceAssetsHidden: false,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds
        )
    }
}

extension MetaAccountModel {
    var supportEthereum: Bool {
        ethereumPublicKey != nil || chainAccounts.first(where: { $0.ethereumBased == true }) != nil
    }
}

extension MetaAccountModel: Identifiable {
    var identifier: String { metaId }
}

extension MetaAccountModel {
    func isVisible(chainAsset: ChainAsset) -> Bool {
        assetsVisibility.first(where: { $0.assetId == chainAsset.identifier })?.hidden == false
    }

    func insertingChainAccount(_ newChainAccount: ChainAccountModel) -> MetaAccountModel {
        var newChainAccounts = chainAccounts.filter {
            $0.chainId != newChainAccount.chainId
        }

        newChainAccounts.insert(newChainAccount)

        return MetaAccountModel(
            metaId: metaId,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: newChainAccounts,
            assetKeysOrder: assetKeysOrder,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds,
            legacyTonAccount: legacyTonAccount
        )
    }

    func replacingChainAccounts(_ newChainAccounts: Set<ChainAccountModel>) -> MetaAccountModel {
        MetaAccountModel(
            metaId: metaId,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: newChainAccounts,
            assetKeysOrder: assetKeysOrder,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds,
            legacyTonAccount: legacyTonAccount
        )
    }

    func replacingEthereumAddress(_ newEthereumAddress: Data?) -> MetaAccountModel {
        MetaAccountModel(
            metaId: metaId,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType,
            substratePublicKey: substratePublicKey,
            ethereumAddress: newEthereumAddress,
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: chainAccounts,
            assetKeysOrder: assetKeysOrder,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds,
            legacyTonAccount: legacyTonAccount
        )
    }

    func replacingEthereumPublicKey(_ newEthereumPublicKey: Data?) -> MetaAccountModel {
        MetaAccountModel(
            metaId: metaId,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: newEthereumPublicKey,
            chainAccounts: chainAccounts,
            assetKeysOrder: assetKeysOrder,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds,
            legacyTonAccount: legacyTonAccount
        )
    }

    func replacingName(_ walletName: String) -> MetaAccountModel {
        MetaAccountModel(
            metaId: metaId,
            name: walletName,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: chainAccounts,
            assetKeysOrder: assetKeysOrder,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds,
            legacyTonAccount: legacyTonAccount
        )
    }

    func replacingAssetKeysOrder(_ newAssetKeysOrder: [String]) -> MetaAccountModel {
        MetaAccountModel(
            metaId: metaId,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: chainAccounts,
            assetKeysOrder: newAssetKeysOrder,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds,
            legacyTonAccount: legacyTonAccount
        )
    }

    func replacingUnusedChainIds(_ newUnusedChainIds: [String]) -> MetaAccountModel {
        MetaAccountModel(
            metaId: metaId,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: chainAccounts,
            assetKeysOrder: assetKeysOrder,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: newUnusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds,
            legacyTonAccount: legacyTonAccount
        )
    }

    func replacingCurrency(_ currency: Currency) -> MetaAccountModel {
        MetaAccountModel(
            metaId: metaId,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: chainAccounts,
            assetKeysOrder: assetKeysOrder,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: currency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds,
            legacyTonAccount: legacyTonAccount
        )
    }

    func replacingNetworkManagmentFilter(_ identifire: String) -> MetaAccountModel {
        MetaAccountModel(
            metaId: metaId,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: chainAccounts,
            assetKeysOrder: assetKeysOrder,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: identifire,
            assetsVisibility: assetsVisibility,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds,
            legacyTonAccount: legacyTonAccount
        )
    }

    func replacingAssetsVisibility(_ newAssetsVisibility: [AssetVisibility]) -> MetaAccountModel {
        MetaAccountModel(
            metaId: metaId,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: chainAccounts,
            assetKeysOrder: assetKeysOrder,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: newAssetsVisibility,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds,
            legacyTonAccount: legacyTonAccount
        )
    }

    func replacingIsBackuped(_ isBackuped: Bool) -> MetaAccountModel {
        MetaAccountModel(
            metaId: metaId,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: chainAccounts,
            assetKeysOrder: assetKeysOrder,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            hasBackup: isBackuped,
            favouriteChainIds: favouriteChainIds,
            legacyTonAccount: legacyTonAccount
        )
    }

    func replacingFavoutites(_ favouriteChainIds: [ChainModel.Id]) -> MetaAccountModel {
        MetaAccountModel(
            metaId: metaId,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: chainAccounts,
            assetKeysOrder: assetKeysOrder,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds,
            legacyTonAccount: legacyTonAccount
        )
    }
}
