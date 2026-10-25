import Foundation
import RobinHood

public enum FilterOption: String, Codable {
    case hideZeroBalance
    case hiddenSectionOpen
}

public typealias MetaAccountId = String

public struct MetaAccountModel: Equatable, Codable, Identifiable {
    public var identifier: String { name }
    public let metaId: MetaAccountId
    public let name: String
    public let substrateAccountId: Data
    public let substrateCryptoType: UInt8
    public let substratePublicKey: Data
    public let ethereumAddress: Data?
    public let ethereumPublicKey: Data?
    public let chainAccounts: Set<ChainAccountModel>
    public let assetKeysOrder: [String]?
    public let assetFilterOptions: [FilterOption]
    public let canExportEthereumMnemonic: Bool
    public let unusedChainIds: [String]?
    public let selectedCurrency: Currency
    public let networkManagmentFilter: String?
    public let assetsVisibility: [AssetVisibility]
    public let zeroBalanceAssetsHidden: Bool
    public let hasBackup: Bool
    public let favouriteChainIds: [ChainModel.Id]

    public init(
        metaId: MetaAccountId,
        name: String,
        substrateAccountId: Data,
        substrateCryptoType: UInt8,
        substratePublicKey: Data,
        ethereumAddress: Data?,
        ethereumPublicKey: Data?,
        chainAccounts: Set<ChainAccountModel>,
        assetKeysOrder: [String]?,
        assetFilterOptions: [FilterOption],
        canExportEthereumMnemonic: Bool,
        unusedChainIds: [String]?,
        selectedCurrency: Currency,
        networkManagmentFilter: ChainModel.Id?,
        assetsVisibility: [AssetVisibility],
        zeroBalanceAssetsHidden: Bool,
        hasBackup: Bool,
        favouriteChainIds: [ChainModel.Id]
    ) {
        self.metaId = metaId
        self.name = name
        self.substrateAccountId = substrateAccountId
        self.substrateCryptoType = substrateCryptoType
        self.substratePublicKey = substratePublicKey
        self.ethereumAddress = ethereumAddress
        self.ethereumPublicKey = ethereumPublicKey
        self.chainAccounts = chainAccounts
        self.assetKeysOrder = assetKeysOrder
        self.assetFilterOptions = assetFilterOptions
        self.canExportEthereumMnemonic = canExportEthereumMnemonic
        self.unusedChainIds = unusedChainIds
        self.selectedCurrency = selectedCurrency
        self.networkManagmentFilter = networkManagmentFilter
        self.assetsVisibility = assetsVisibility
        self.zeroBalanceAssetsHidden = zeroBalanceAssetsHidden
        self.hasBackup = hasBackup
        self.favouriteChainIds = favouriteChainIds
    }
}

extension MetaAccountModel {
    var supportEthereum: Bool {
        ethereumPublicKey != nil || chainAccounts.first(where: { $0.ethereumBased == true }) != nil
    }
}

// MARK: - Account request

public struct ChainAccountRequest {
    public let chainId: ChainModel.Id
    public let addressPrefix: UInt16
    public let isEthereumBased: Bool
    public let accountId: AccountId?
}

extension MetaAccountModel {
    public func fetch(for request: ChainAccountRequest) -> ChainAccountResponse? {
        if let replacedAccount = chainAccounts.first(where: { $0.chainId == request.chainId }) {
            return response(for: replacedAccount, request: request)
        }

        if request.isEthereumBased {
            return responseForEthereumBased(request)
        }

        return responseForSubstrate(request)
    }

    // MARK: - Private methods

    private func response(
        for chainAccount: ChainAccountModel,
        request: ChainAccountRequest
    ) -> ChainAccountResponse? {
        guard let cryptoType = CryptoType(rawValue: chainAccount.cryptoType) else {
            return nil
        }

        return ChainAccountResponse(
            chainId: request.chainId,
            accountId: chainAccount.accountId,
            publicKey: chainAccount.publicKey,
            name: name,
            cryptoType: cryptoType,
            addressPrefix: request.addressPrefix,
            isEthereumBased: request.isEthereumBased,
            isChainAccount: true,
            walletId: metaId
        )
    }

    private func responseForEthereumBased(_ request: ChainAccountRequest) -> ChainAccountResponse? {
        guard let publicKey = ethereumPublicKey, let accountId = ethereumAddress else {
            return nil
        }

        return ChainAccountResponse(
            chainId: request.chainId,
            accountId: accountId,
            publicKey: publicKey,
            name: name,
            cryptoType: .ecdsa,
            addressPrefix: request.addressPrefix,
            isEthereumBased: request.isEthereumBased,
            isChainAccount: false,
            walletId: metaId
        )
    }

    private func responseForSubstrate(_ request: ChainAccountRequest) -> ChainAccountResponse? {
        guard let cryptoType = CryptoType(rawValue: substrateCryptoType) else {
            return nil
        }

        return ChainAccountResponse(
            chainId: request.chainId,
            accountId: substrateAccountId,
            publicKey: substratePublicKey,
            name: name,
            cryptoType: cryptoType,
            addressPrefix: request.addressPrefix,
            isEthereumBased: false,
            isChainAccount: false,
            walletId: metaId
        )
    }
}

// MARK: - Replacing

public extension MetaAccountModel {
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
            assetFilterOptions: assetFilterOptions,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            zeroBalanceAssetsHidden: zeroBalanceAssetsHidden,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds
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
            assetFilterOptions: assetFilterOptions,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            zeroBalanceAssetsHidden: zeroBalanceAssetsHidden,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds
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
            assetFilterOptions: assetFilterOptions,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            zeroBalanceAssetsHidden: zeroBalanceAssetsHidden,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds
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
            assetFilterOptions: assetFilterOptions,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            zeroBalanceAssetsHidden: zeroBalanceAssetsHidden,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds
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
            assetFilterOptions: assetFilterOptions,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            zeroBalanceAssetsHidden: zeroBalanceAssetsHidden,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds
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
            assetFilterOptions: assetFilterOptions,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: newUnusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            zeroBalanceAssetsHidden: zeroBalanceAssetsHidden,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds
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
            assetFilterOptions: assetFilterOptions,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: currency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            zeroBalanceAssetsHidden: zeroBalanceAssetsHidden,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds
        )
    }

    func replacingAssetsFilterOptions(_ options: [FilterOption]) -> MetaAccountModel {
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
            assetFilterOptions: options,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            zeroBalanceAssetsHidden: zeroBalanceAssetsHidden,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds
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
            assetFilterOptions: assetFilterOptions,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: identifire,
            assetsVisibility: assetsVisibility,
            zeroBalanceAssetsHidden: zeroBalanceAssetsHidden,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds
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
            assetFilterOptions: assetFilterOptions,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: newAssetsVisibility,
            zeroBalanceAssetsHidden: zeroBalanceAssetsHidden,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds
        )
    }

    func replacingZeroBalanceAssetsHidden(_ newZeroBalanceAssetsHidden: Bool) -> MetaAccountModel {
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
            assetFilterOptions: assetFilterOptions,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            zeroBalanceAssetsHidden: newZeroBalanceAssetsHidden,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds
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
            assetFilterOptions: assetFilterOptions,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            zeroBalanceAssetsHidden: zeroBalanceAssetsHidden,
            hasBackup: isBackuped,
            favouriteChainIds: favouriteChainIds
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
            assetFilterOptions: assetFilterOptions,
            canExportEthereumMnemonic: canExportEthereumMnemonic,
            unusedChainIds: unusedChainIds,
            selectedCurrency: selectedCurrency,
            networkManagmentFilter: networkManagmentFilter,
            assetsVisibility: assetsVisibility,
            zeroBalanceAssetsHidden: zeroBalanceAssetsHidden,
            hasBackup: hasBackup,
            favouriteChainIds: favouriteChainIds
        )
    }
}
