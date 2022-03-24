import Foundation

protocol ManageAssetsViewModelFactoryProtocol {
    func buildManageAssetsViewModel(
        selectedMetaAccount: MetaAccountModel?,
        chains: [ChainModel],
        locale: Locale,
        accountInfos: [ChainModel.Id: AccountInfo]?,
        sortedKeys: [String]?,
        cellsDelegate: ManageAssetsTableViewCellModelDelegate?
    ) -> ManageAssetsViewModel
}

final class ManageAssetsViewModelFactory {
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }

    private func buildManageAssetsCellViewModel(
        chainAsset: ChainAsset,
        accountInfo: AccountInfo?,
        locale _: Locale,
        delegate: ManageAssetsTableViewCellModelDelegate?
    ) -> ManageAssetsTableViewCellModel {
        let icon = chainAsset.chain.icon.map { buildRemoteImageViewModel(url: $0) }
        let title = chainAsset.chain.name
        let balance = getBalanceString(
            for: chainAsset,
            accountInfo: accountInfo
        )

        let options = buildChainOptionsViewModel(chainAsset: chainAsset)

        let model = ManageAssetsTableViewCellModel(
            chain: chainAsset.chain,
            asset: chainAsset.asset,
            assetName: title,
            assetInfo: chainAsset.asset.displayInfo(with: chainAsset.chain.icon),
            imageViewModel: icon,
            balanceString: balance,
            options: options
        )
        
        model.delegate = delegate
        
        return model
    }
}

extension ManageAssetsViewModelFactory {
    private func getBalanceString(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?
    ) -> String? {
        let balance = getBalance(for: chainAsset, accountInfo: accountInfo)
        let digits = balance > 0 ? 4 : 0
        let balanceString = balance.toString(digits: digits) ?? "0"
        let parts: [String] = [balanceString, chainAsset.asset.name]
        return parts.joined(separator: " ")
    }

    private func getBalance(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?
    ) -> Decimal {
        guard let accountInfo = accountInfo else {
            return Decimal.zero
        }

        let assetInfo = chainAsset.asset.displayInfo

        let balance = Decimal.fromSubstrateAmount(
            accountInfo.data.total,
            precision: assetInfo.assetPrecision
        ) ?? 0

        return balance
    }

    private func getUsdBalance(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?,
        locale _: Locale
    ) -> Decimal {
        let assetInfo = chainAsset.asset.displayInfo

        var balance: Decimal
        if let accountInfo = accountInfo {
            balance = Decimal.fromSubstrateAmount(
                accountInfo.data.total,
                precision: assetInfo.assetPrecision
            ) ?? 0
        } else {
            balance = Decimal.zero
        }

        guard let priceDecimal = chainAsset.asset.price else {
            return Decimal.zero
        }

        let totalBalanceDecimal = priceDecimal * balance

        return totalBalanceDecimal
    }
}

extension ManageAssetsViewModelFactory: ManageAssetsViewModelFactoryProtocol {
    func buildManageAssetsViewModel(
        selectedMetaAccount: MetaAccountModel?,
        chains: [ChainModel],
        locale: Locale,
        accountInfos: [ChainModel.Id: AccountInfo]?,
        sortedKeys: [String]?,
        cellsDelegate: ManageAssetsTableViewCellModelDelegate?
    ) -> ManageAssetsViewModel {
        let chainAssets = chains.map { chain in
            chain.assets.compactMap { asset in
                ChainAsset(chain: chain, asset: asset.asset)
            }
        }.reduce([], +)

        var balanceByChainAsset: [ChainAsset: Decimal] = [:]
        var usdBalanceByChainAsset: [ChainAsset: Decimal] = [:]

        chainAssets.forEach { chainAsset in
            let accountInfo: AccountInfo? = accountInfos?[chainAsset.chain.chainId]

            usdBalanceByChainAsset[chainAsset] = getUsdBalance(
                for: chainAsset,
                accountInfo: accountInfo,
                locale: locale
            )

            balanceByChainAsset[chainAsset] = getBalance(
                for: chainAsset,
                accountInfo: accountInfo
            )
        }

        let chainAssetsSorted = chainAssets
            .sorted { ca1, ca2 in
                if let sortedKeys = sortedKeys, let accountId = selectedMetaAccount?.substrateAccountId {
                    var orderByKey: [String: Int] = [:]
                    for (index, key) in sortedKeys.enumerated() {
                        orderByKey[key] = index
                    }

                    return orderByKey[ca1.asset.sortKey(accountId: accountId)] ?? Int.max < orderByKey[ca2.asset.sortKey(accountId: accountId)] ?? Int.max
                } else {
                    return (
                        usdBalanceByChainAsset[ca1] ?? Decimal.zero,
                        balanceByChainAsset[ca1] ?? Decimal.zero,
                        ca2.chain.isTestnet.intValue,
                        ca1.chain.isPolkadotOrKusama.intValue,
                        ca2.chain.name
                    ) > (
                        usdBalanceByChainAsset[ca2] ?? Decimal.zero,
                        balanceByChainAsset[ca2] ?? Decimal.zero,
                        ca1.chain.isTestnet.intValue,
                        ca2.chain.isPolkadotOrKusama.intValue,
                        ca1.chain.name
                    )
                }
            }

        let viewModels: [ManageAssetsTableViewCellModel] = chainAssetsSorted.map { chainAsset in
            buildManageAssetsCellViewModel(
                chainAsset: chainAsset,
                accountInfo: accountInfos?[chainAsset.chain.chainId],
                locale: locale,
                delegate: cellsDelegate
            )
        }

        return ManageAssetsViewModel(cellModels: viewModels)
    }
}

extension ManageAssetsViewModelFactory: RemoteImageViewModelFactoryProtocol {}
extension ManageAssetsViewModelFactory: ChainOptionsViewModelFactoryProtocol {}
