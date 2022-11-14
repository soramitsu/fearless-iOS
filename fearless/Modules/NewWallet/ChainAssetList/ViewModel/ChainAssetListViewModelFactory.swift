import Foundation
import SoraFoundation

// swiftlint:disable function_parameter_count function_body_length
protocol ChainAssetListViewModelFactoryProtocol {
    func buildViewModel(
        displayType: AssetListDisplayType,
        selectedMetaAccount: MetaAccountModel,
        chainAssets: [ChainAsset],
        locale: Locale,
        accountInfos: [ChainAssetKey: AccountInfo?],
        prices: PriceDataUpdated,
        chainsWithIssues: [ChainModel.Id],
        chainsWithMissingAccounts: [ChainModel.Id]
    ) -> ChainAssetListViewModel
}

final class ChainAssetListViewModelFactory: ChainAssetListViewModelFactoryProtocol {
    private let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }

    func buildViewModel(
        displayType: AssetListDisplayType,
        selectedMetaAccount: MetaAccountModel,
        chainAssets: [ChainAsset],
        locale: Locale,
        accountInfos: [ChainAssetKey: AccountInfo?],
        prices: PriceDataUpdated,
        chainsWithIssues: [ChainModel.Id],
        chainsWithMissingAccounts: [ChainModel.Id]
    ) -> ChainAssetListViewModel {
        var fiatBalanceByChainAsset: [ChainAsset: Decimal] = [:]

        chainAssets.forEach { chainAsset in
            guard let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return
            }
            let accountInfo = accountInfos[chainAsset.uniqueKey(accountId: accountId)] ?? nil

            let priceData = prices.pricesData.first(where: { $0.priceId == chainAsset.asset.priceId })
            fiatBalanceByChainAsset[chainAsset] = getFiatBalance(
                for: chainAsset,
                accountInfo: accountInfo,
                priceData: priceData
            )
        }

        var utilityChainAssets = chainAssets
        switch displayType {
        case .chain:
            break
        case .assetChains:
            utilityChainAssets = filteredUnique(chainAssets: chainAssets.filter { $0.isUtility == true })
            utilityChainAssets = sortAssetList(
                wallet: selectedMetaAccount,
                chainAssets: utilityChainAssets,
                accountInfos: accountInfos,
                priceData: prices.pricesData
            )
        }

        let chainAssetCellModels: [ChainAccountBalanceCellViewModel] = utilityChainAssets.compactMap { chainAsset in
            let priceId = chainAsset.asset.priceId ?? chainAsset.asset.id
            let priceData = prices.pricesData.first(where: { $0.priceId == priceId })

            return buildChainAccountBalanceCellViewModel(
                chainAssets: chainAssets,
                chainAsset: chainAsset,
                priceData: priceData,
                priceDataUpdated: prices.updated,
                accountInfos: accountInfos,
                locale: locale,
                currency: selectedMetaAccount.selectedCurrency,
                selectedMetaAccount: selectedMetaAccount,
                chainsWithIssues: chainsWithIssues,
                chainsWithMissingAccounts: chainsWithMissingAccounts
            )
        }

        let cellModelsDivide = chainAssetCellModels.divide(predicate: { $0.isHidden || $0.isUnused })
        let activeSectionCellModels: [ChainAccountBalanceCellViewModel] = cellModelsDivide.remainder
        let hiddenSectionCellModels: [ChainAccountBalanceCellViewModel] = cellModelsDivide.slice

        let enabledAccountsInfosKeys = accountInfos.keys.filter { key in
            chainAssets.contains { chainAsset in
                guard
                    let accountId = selectedMetaAccount.fetch(
                        for: chainAsset.chain.accountRequest()
                    )?.accountId else {
                    return false
                }
                let chainAssetKey = chainAsset.uniqueKey(accountId: accountId)
                return key == chainAssetKey
            }
        }

        let isColdBoot = enabledAccountsInfosKeys.count != fiatBalanceByChainAsset.count
        return ChainAssetListViewModel(
            sections: [
                .active,
                .hidden
            ],
            cellsForSections: [
                .active: activeSectionCellModels,
                .hidden: hiddenSectionCellModels
            ],
            isColdBoot: isColdBoot
        )
    }
}

private extension ChainAssetListViewModelFactory {
    func tokenFormatter(
        for currency: Currency,
        locale: Locale
    ) -> TokenFormatter {
        let displayInfo = AssetBalanceDisplayInfo.forCurrency(currency)
        let tokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: displayInfo)
        let tokenFormatterValue = tokenFormatter.value(for: locale)
        return tokenFormatterValue
    }

    func buildChainAccountBalanceCellViewModel(
        chainAssets: [ChainAsset],
        chainAsset: ChainAsset,
        priceData: PriceData?,
        priceDataUpdated: Bool,
        accountInfos: [ChainAssetKey: AccountInfo?],
        locale: Locale,
        currency: Currency,
        selectedMetaAccount: MetaAccountModel,
        chainsWithIssues: [ChainModel.Id],
        chainsWithMissingAccounts: [ChainModel.Id]
    ) -> ChainAccountBalanceCellViewModel? {
        var accountInfo: AccountInfo?
        if let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            let key = chainAsset.uniqueKey(accountId: accountId)
            accountInfo = accountInfos[key] ?? nil
        }

        let priceAttributedString = getPriceAttributedString(
            priceData: priceData,
            locale: locale,
            currency: currency
        )
        let options = buildChainOptionsViewModel(chainAsset: chainAsset)

        var isColdBoot = true
        if let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            let key = chainAsset.uniqueKey(accountId: accountId)
            isColdBoot = !accountInfos.keys.contains(key)
        }

        let containsChainAssets = chainAssets.filter {
            $0.asset.name == chainAsset.asset.name
        }
        let isNetworkIssues = containsChainAssets.first(where: {
            chainsWithIssues.contains($0.chain.chainId)
        }) != nil
        let isMissingAccount = containsChainAssets.first(where: {
            chainsWithMissingAccounts.contains($0.chain.chainId)
        }) != nil

        if chainsWithMissingAccounts.contains(chainAsset.chain.chainId) {
            isColdBoot = !isMissingAccount
        }

        let totalAssetBalance = getBalanceString(
            for: containsChainAssets,
            accountInfos: accountInfos,
            locale: locale,
            selectedMetaAccount: selectedMetaAccount
        )

        let totalFiatBalance = getFiatBalanceString(
            for: containsChainAssets,
            accountInfos: accountInfos,
            priceData: priceData,
            locale: locale,
            currency: currency,
            selectedMetaAccount: selectedMetaAccount
        )

        var isUnused = false
        if let unusedChainIds = selectedMetaAccount.unusedChainIds {
            isUnused = unusedChainIds.contains(chainAsset.chain.chainId)
        }

        let viewModel = ChainAccountBalanceCellViewModel(
            assetContainsChainAssets: containsChainAssets,
            chainAsset: chainAsset,
            assetName: chainAsset.chain.name,
            assetInfo: chainAsset.asset.displayInfo(with: chainAsset.chain.icon),
            imageViewModel: (chainAsset.asset.icon ?? chainAsset.chain.icon).map { buildRemoteImageViewModel(url: $0) },
            balanceString: .init(
                value: .text(totalAssetBalance),
                isUpdated: priceDataUpdated
            ),
            priceAttributedString: .init(
                value: .attributed(priceAttributedString),
                isUpdated: priceDataUpdated
            ),
            totalAmountString: .init(
                value: .text(totalFiatBalance),
                isUpdated: priceDataUpdated
            ),
            options: options,
            isColdBoot: isColdBoot,
            priceDataWasUpdated: priceDataUpdated,
            isNetworkIssues: isNetworkIssues,
            isMissingAccount: isMissingAccount,
            isHidden: checkForHide(chainAsset: chainAsset, selectedMetaAccount: selectedMetaAccount),
            isUnused: isUnused,
            locale: locale
        )

        if selectedMetaAccount.assetFilterOptions.contains(.hideZeroBalance),
           accountInfo == nil,
           !isColdBoot {
            return nil
        } else {
            return viewModel
        }
    }

    func sortAssetList(
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        priceData: [PriceData]
    ) -> [ChainAsset] {
        func fetchAccountIds(
            for ca1: ChainAsset,
            for ca2: ChainAsset
        ) -> (ca1AccountId: AccountId, ca2AccountId: AccountId)? {
            let ca1Request = ca1.chain.accountRequest()
            let ca2Request = ca2.chain.accountRequest()

            guard
                let ca1AccountId = wallet.fetch(for: ca1Request)?.accountId,
                let ca2AccountId = wallet.fetch(for: ca2Request)?.accountId
            else {
                return nil
            }

            return (ca1AccountId: ca1AccountId, ca2AccountId: ca2AccountId)
        }

        func sortByOrderKey(
            ca1: ChainAsset,
            ca2: ChainAsset,
            orderByKey: [String: Int]
        ) -> Bool {
            guard let accountIds = fetchAccountIds(for: ca1, for: ca2) else {
                return false
            }

            let ca1Order = orderByKey[ca1.uniqueKey(accountId: accountIds.ca1AccountId)] ?? Int.max
            let ca2Order = orderByKey[ca2.uniqueKey(accountId: accountIds.ca2AccountId)] ?? Int.max

            return ca1Order < ca2Order
        }

        func sortByDefaultList(
            ca1: ChainAsset,
            ca2: ChainAsset
        ) -> Bool {
            guard let accountIds = fetchAccountIds(for: ca1, for: ca2) else {
                return false
            }

            let ca1AccountInfo = accountInfos[ca1.uniqueKey(accountId: accountIds.ca1AccountId)] ?? nil
            let ca2AccountInfo = accountInfos[ca2.uniqueKey(accountId: accountIds.ca2AccountId)] ?? nil

            let ca1PriceId = ca1.asset.priceId ?? ca1.asset.id
            let ca1PriceData = priceData.first(where: { $0.priceId == ca1PriceId })

            let ca2PriceId = ca2.asset.priceId ?? ca2.asset.id
            let ca2PriceData = priceData.first(where: { $0.priceId == ca2PriceId })

            let fiatBalanceCa1 = getFiatBalance(for: ca1, accountInfo: ca1AccountInfo, priceData: ca1PriceData)
            let fiatBalanceCa2 = getFiatBalance(for: ca2, accountInfo: ca2AccountInfo, priceData: ca2PriceData)

            let balanceCa1 = getBalance(for: ca1, accountInfo: ca1AccountInfo)
            let balanceCa2 = getBalance(for: ca2, accountInfo: ca2AccountInfo)

            return (
                fiatBalanceCa1,
                balanceCa1,
                ca1.chain.isTestnet.intValue,
                ca1.chain.isPolkadotOrKusama.intValue,
                ca1.chain.name
            ) > (
                fiatBalanceCa2,
                balanceCa2,
                ca2.chain.isTestnet.intValue,
                ca2.chain.isPolkadotOrKusama.intValue,
                ca2.chain.name
            )
        }

        var orderByKey: [String: Int]?

        if let sortedKeys = wallet.assetKeysOrder {
            orderByKey = [:]
            for (index, key) in sortedKeys.enumerated() {
                orderByKey?[key] = index
            }
        }

        let chainAssetsSorted = chainAssets
            .sorted { ca1, ca2 in
                if let orderByKey = orderByKey {
                    return sortByOrderKey(ca1: ca1, ca2: ca2, orderByKey: orderByKey)
                } else {
                    return sortByDefaultList(ca1: ca1, ca2: ca2)
                }
            }

        return chainAssetsSorted
    }

    func getBalanceString(
        for chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        locale: Locale,
        selectedMetaAccount: MetaAccountModel
    ) -> String? {
        let totalAssetBalance = chainAssets.compactMap { chainAsset -> Decimal in
            if let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId,
               let accountInfo = accountInfos[chainAsset.uniqueKey(accountId: accountId)] {
                return getBalance(for: chainAsset, accountInfo: accountInfo)
            }

            return Decimal.zero
        }.reduce(0, +)

        let digits = totalAssetBalance > 0 ? 4 : 0
        return totalAssetBalance.toString(locale: locale, digits: digits)
    }

    func getBalance(
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

    func getFiatBalanceString(
        for chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        priceData: PriceData?,
        locale: Locale,
        currency: Currency,
        selectedMetaAccount: MetaAccountModel
    ) -> String? {
        let totalFiatBalance = chainAssets.compactMap { chainAsset -> Decimal? in
            if let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId,
               let accountInfo = accountInfos[chainAsset.uniqueKey(accountId: accountId)] {
                return getFiatBalance(
                    for: chainAsset,
                    accountInfo: accountInfo,
                    priceData: priceData
                )
            }

            return nil
        }.reduce(0, +)

        guard totalFiatBalance != .zero else { return nil }

        let balanceTokenFormatterValue = tokenFormatter(for: currency, locale: locale)
        return balanceTokenFormatterValue.stringFromDecimal(totalFiatBalance)
    }

    func getFiatBalance(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?,
        priceData: PriceData?
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

        guard let price = priceData?.price,
              let priceDecimal = Decimal(string: price) else {
            return Decimal.zero
        }

        let totalBalanceDecimal = priceDecimal * balance

        return totalBalanceDecimal
    }

    func getPriceAttributedString(
        priceData: PriceData?,
        locale: Locale,
        currency: Currency
    ) -> NSAttributedString? {
        let balanceTokenFormatterValue = tokenFormatter(for: currency, locale: locale)

        guard let priceData = priceData,
              let priceDecimal = Decimal(string: priceData.price) else {
            return nil
        }

        let changeString: String = priceData.fiatDayChange.map {
            let percentValue = $0 / 100
            return percentValue.percentString(locale: locale) ?? ""
        } ?? ""

        let priceString: String = balanceTokenFormatterValue.stringFromDecimal(priceDecimal) ?? ""
        let priceWithChangeString = [priceString, changeString].joined(separator: " ")
        let priceWithChangeAttributed = NSMutableAttributedString(string: priceWithChangeString)

        let color = (priceData.fiatDayChange ?? 0) > 0
            ? R.color.colorGreen()
            : R.color.colorRed()

        if let color = color {
            priceWithChangeAttributed.addAttributes(
                [NSAttributedString.Key.foregroundColor: color],
                range: NSRange(
                    location: priceString.count + 1,
                    length: changeString.count
                )
            )
        }

        return priceWithChangeAttributed
    }

    func filteredUnique(chainAssets: [ChainAsset]) -> [ChainAsset] {
        let assetNamesSet: Set<String> = Set(chainAssets.map { $0.asset.name })
        let result = assetNamesSet.compactMap { name in
            chainAssets.first { chainAsset in
                chainAsset.asset.name == name && chainAsset.asset.chainId == chainAsset.chain.chainId
            }
        }
        return result
    }

    func checkForHide(chainAsset: ChainAsset, selectedMetaAccount: MetaAccountModel) -> Bool {
        let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId

        if let assetIdsEnabled = selectedMetaAccount.assetIdsEnabled, let accountId = accountId {
            return !assetIdsEnabled.contains { assetId in
                assetId == chainAsset.uniqueKey(accountId: accountId)
            }
        }
        return false
    }
}

extension ChainAssetListViewModelFactory: RemoteImageViewModelFactoryProtocol {}
extension ChainAssetListViewModelFactory: ChainOptionsViewModelFactoryProtocol {}
