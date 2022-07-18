import Foundation

// swiftlint:disable function_parameter_count
protocol ManageAssetsViewModelFactoryProtocol {
    func buildManageAssetsViewModel(
        selectedMetaAccount: MetaAccountModel,
        chains: [ChainModel],
        accountInfos: [ChainAssetKey: AccountInfo?],
        sortedKeys: [String]?,
        assetIdsEnabled: [String]?,
        cellsDelegate: ManageAssetsTableViewCellModelDelegate?,
        filter: String?,
        locale: Locale?,
        filterOptions: [FilterOption],
        chainIdForFilter: String?
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
        delegate: ManageAssetsTableViewCellModelDelegate?,
        assetEnabled: Bool,
        selectedMetaAccount: MetaAccountModel?,
        locale: Locale?
    ) -> ManageAssetsTableViewCellModel {
        let icon = (chainAsset.asset.icon ?? chainAsset.chain.icon).map { buildRemoteImageViewModel(url: $0) }
        let title = chainAsset.chain.name
        let balance = getBalanceString(
            for: chainAsset,
            accountInfo: accountInfo,
            locale: locale
        )

        let options = buildChainOptionsViewModel(chainAsset: chainAsset)

        let model = ManageAssetsTableViewCellModel(
            chainAsset: chainAsset,
            assetName: title,
            assetInfo: chainAsset.asset.displayInfo(with: chainAsset.chain.icon),
            imageViewModel: icon,
            balanceString: balance,
            options: options,
            assetEnabled: assetEnabled,
            accountMissing: selectedMetaAccount?.fetch(for: chainAsset.chain.accountRequest())?.accountId == nil,
            chainUnused: selectedMetaAccount?.unusedChainIds?.contains(chainAsset.chain.chainId) == true,
            locale: locale
        )

        model.delegate = delegate

        return model
    }
}

extension ManageAssetsViewModelFactory {
    private func getBalanceString(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?,
        locale: Locale?
    ) -> String? {
        let balance = getBalance(for: chainAsset, accountInfo: accountInfo)
        let digits = balance > 0 ? 4 : 0
        let balanceString = balance.toString(locale: locale, digits: digits) ?? "0"
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
        accountInfo: AccountInfo?
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

// swiftlint:disable function_body_length
extension ManageAssetsViewModelFactory: ManageAssetsViewModelFactoryProtocol {
    func buildManageAssetsViewModel(
        selectedMetaAccount: MetaAccountModel,
        chains: [ChainModel],
        accountInfos: [ChainAssetKey: AccountInfo?],
        sortedKeys: [String]?,
        assetIdsEnabled: [String]?,
        cellsDelegate: ManageAssetsTableViewCellModelDelegate?,
        filter: String?,
        locale: Locale?,
        filterOptions: [FilterOption],
        chainIdForFilter: String?
    ) -> ManageAssetsViewModel {
        var chainAssets = chains
            .filter { $0.chainId == chainIdForFilter || chainIdForFilter == nil }
            .map { chain in
                chain.assets.compactMap { asset in
                    ChainAsset(chain: chain, asset: asset.asset)
                }
            }.reduce([], +)

        if let filter = filter?.lowercased(), !filter.isEmpty {
            chainAssets = chainAssets.filter {
                $0.asset.name.lowercased().contains(filter)
                    || $0.chain.name.lowercased().contains(filter)
            }
        }

        var balanceByChainAsset: [ChainAsset: Decimal] = [:]
        var usdBalanceByChainAsset: [ChainAsset: Decimal] = [:]

        chainAssets.forEach { chainAsset in
            guard let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return
            }
            let accountInfo: AccountInfo? = accountInfos[chainAsset.uniqueKey(accountId: accountId)] ?? nil

            usdBalanceByChainAsset[chainAsset] = getUsdBalance(
                for: chainAsset,
                accountInfo: accountInfo
            )

            balanceByChainAsset[chainAsset] = getBalance(
                for: chainAsset,
                accountInfo: accountInfo
            )
        }

        var orderByKey: [String: Int]?

        if let sortedKeys = sortedKeys {
            orderByKey = [:]
            for (index, key) in sortedKeys.enumerated() {
                orderByKey?[key] = index
            }
        }

        let chainAssetsSorted = chainAssets
            .sorted { ca1, ca2 in
                if let orderByKey = orderByKey {
                    let accountId = selectedMetaAccount.substrateAccountId

                    return orderByKey[ca1.uniqueKey(accountId: accountId)]
                        ?? Int.max < orderByKey[ca2.uniqueKey(accountId: accountId)]
                        ?? Int.max
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

        let viewModels: [ManageAssetsTableViewCellModel] = chainAssetsSorted.compactMap { chainAsset in
            let substrateUniqueKey = chainAsset.uniqueKey(accountId: selectedMetaAccount.substrateAccountId)
            let enabled = assetIdsEnabled == nil || assetIdsEnabled?.contains(substrateUniqueKey) == true

            var accountInfo: AccountInfo?
            if let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId {
                accountInfo = accountInfos[chainAsset.uniqueKey(accountId: accountId)] ?? nil
            }

            let viewModel = buildManageAssetsCellViewModel(
                chainAsset: chainAsset,
                accountInfo: accountInfo,
                delegate: cellsDelegate,
                assetEnabled: enabled,
                selectedMetaAccount: selectedMetaAccount,
                locale: locale
            )

            if
                filterOptions.contains(.hideZeroBalance),
                accountInfo == nil {
                return nil
            } else {
                return viewModel
            }
        }

        let missingSection = ManageAssetsTableSection(cellModels: viewModels.filter {
            selectedMetaAccount.fetch(for: $0.chainAsset.chain.accountRequest()) == nil
                && (selectedMetaAccount.unusedChainIds ?? []).contains($0.chainAsset.chain.chainId) == false
        })
        let normalSection = ManageAssetsTableSection(cellModels: viewModels.filter {
            selectedMetaAccount.fetch(for: $0.chainAsset.chain.accountRequest()) != nil
                || selectedMetaAccount.unusedChainIds?.contains($0.chainAsset.chain.chainId) == true
        })

        let applyEnabled = selectedMetaAccount.assetIdsEnabled != assetIdsEnabled
            || selectedMetaAccount.assetKeysOrder != sortedKeys
            || selectedMetaAccount.assetFilterOptions != filterOptions

        let selectedChain = createSelectedChainModel(
            from: chains.filter { $0.chainId == chainIdForFilter || chainIdForFilter == nil },
            locale: locale
        )

        return ManageAssetsViewModel(
            sections: [missingSection, normalSection],
            applyEnabled: applyEnabled,
            selectedChain: selectedChain
        )
    }

    private func createSelectedChainModel(
        from chains: [ChainModel],
        locale: Locale?
    ) -> SelectedChainModel {
        guard chains.count == 1, let selectedChain = chains.first else {
            return SelectedChainModel(
                chainId: nil,
                title: R.string.localizable.chainSelectionAllNetworks(preferredLanguages: locale?.rLanguages),
                icon: nil
            )
        }
        return SelectedChainModel(
            chainId: selectedChain.chainId,
            title: selectedChain.name,
            icon: selectedChain.icon.map { RemoteImageViewModel(url: $0) }
        )
    }
}

extension ManageAssetsViewModelFactory: RemoteImageViewModelFactoryProtocol {}
extension ManageAssetsViewModelFactory: ChainOptionsViewModelFactoryProtocol {}
