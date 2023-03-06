import Foundation
import SoraFoundation
import SoraKeystore
import BigInt

// swiftlint:disable function_parameter_count function_body_length
protocol ChainAssetListViewModelFactoryProtocol {
    func buildViewModel(
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset],
        locale: Locale,
        accountInfos: [ChainAssetKey: AccountInfo?],
        prices: PriceDataUpdated,
        chainsWithIssues: [ChainModel.Id],
        chainsWithMissingAccounts: [ChainModel.Id]
    ) -> ChainAssetListViewModel
}

final class ChainAssetListViewModelFactory: ChainAssetListViewModelFactoryProtocol {
    struct AssetChainAssets {
        let chainAssets: [ChainAsset]
        let mainChainAsset: ChainAsset
        let totalBalance: Decimal
        let totalFiatBalance: Decimal
    }

    private let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    private var polkadotChainId: String?
    private let settings: SettingsManagerProtocol

    init(
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        settings: SettingsManagerProtocol
    ) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.settings = settings
    }

    func buildViewModel(
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset],
        locale: Locale,
        accountInfos: [ChainAssetKey: AccountInfo?],
        prices: PriceDataUpdated,
        chainsWithIssues: [ChainModel.Id],
        chainsWithMissingAccounts: [ChainModel.Id]
    ) -> ChainAssetListViewModel {
        var fiatBalanceByChainAsset: [ChainAsset: Decimal] = [:]

        chainAssets.forEach { chainAsset in
            guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
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

        if let polkadotId = chainAssets.first { chain in
            chain.isUtility && chain.chain.name.lowercased() == "polkadot"
        }?.chain.chainId {
            self.polkadotChainId = polkadotId
        }

        let assetChainAssetsArray = createAssetChainAssets(
            from: chainAssets,
            accountInfos: accountInfos,
            pricesData: prices.pricesData,
            wallet: wallet
        )

        let sortedChainAssets = sortAssetList(
            wallet: wallet,
            chainAssets: assetChainAssetsArray
        )

        let chainAssetCellModels: [ChainAccountBalanceCellViewModel] = sortedChainAssets.compactMap { chainAsset in
            let priceId = chainAsset.asset.priceId ?? chainAsset.asset.id
            let priceData = prices.pricesData.first(where: { $0.priceId == priceId })

            return buildChainAccountBalanceCellViewModel(
                chainAssets: chainAssets,
                chainAsset: chainAsset,
                priceData: priceData,
                priceDataUpdated: prices.updated,
                accountInfos: accountInfos,
                locale: locale,
                currency: wallet.selectedCurrency,
                wallet: wallet,
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
                    let accountId = wallet.fetch(
                        for: chainAsset.chain.accountRequest()
                    )?.accountId else {
                    return false
                }
                let chainAssetKey = chainAsset.uniqueKey(accountId: accountId)
                return key == chainAssetKey
            }
        }

        let isColdBoot = enabledAccountsInfosKeys.count != fiatBalanceByChainAsset.count
        let hiddenSectionIsOpen = wallet.assetFilterOptions.contains(.hiddenSectionOpen)
        var hiddenSectionState: HiddenSectionState = hiddenSectionIsOpen
            ? .expanded
            : .hidden

        if hiddenSectionCellModels.isEmpty {
            hiddenSectionState = .empty
        }
        return ChainAssetListViewModel(
            sections: [
                .active,
                .hidden
            ],
            cellsForSections: [
                .active: activeSectionCellModels,
                .hidden: hiddenSectionCellModels
            ],
            isColdBoot: isColdBoot,
            hiddenSectionState: hiddenSectionState
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
        wallet: MetaAccountModel,
        chainsWithIssues: [ChainModel.Id],
        chainsWithMissingAccounts: [ChainModel.Id]
    ) -> ChainAccountBalanceCellViewModel? {
        var accountInfo: AccountInfo?
        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
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
        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
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
                || wallet.unusedChainIds.or([]).contains($0.chain.chainId)
        }) != nil

        if
            chainsWithMissingAccounts.contains(chainAsset.chain.chainId)
            || wallet.unusedChainIds.or([]).contains(chainAsset.chain.chainId) {
            isColdBoot = !isMissingAccount
        }

        let totalAssetBalance = getBalanceString(
            for: containsChainAssets,
            accountInfos: accountInfos,
            locale: locale,
            wallet: wallet
        )

        let totalFiatBalance = getFiatBalanceString(
            for: containsChainAssets,
            accountInfos: accountInfos,
            priceData: priceData,
            locale: locale,
            currency: currency,
            wallet: wallet
        )

        var isUnused = false
        if let unusedChainIds = wallet.unusedChainIds {
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
            isHidden: checkForHide(chainAsset: chainAsset, wallet: wallet),
            isUnused: isUnused,
            locale: locale
        )

        if settings.shouldHideZeroBalanceAssets == true,
           accountInfo == nil || accountInfo?.data.free == BigUInt.zero,
           !isColdBoot {
            return nil
        } else {
            return viewModel
        }
    }

    func sortAssetList(
        wallet: MetaAccountModel,
        chainAssets: [AssetChainAssets]
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
            aca1: AssetChainAssets,
            aca2: AssetChainAssets,
            orderByKey: [String: Int]
        ) -> Bool {
            guard let accountIds = fetchAccountIds(for: aca1.mainChainAsset, for: aca2.mainChainAsset) else {
                return false
            }

            let aca1Order = orderByKey[aca1.mainChainAsset.uniqueKey(accountId: accountIds.ca1AccountId)] ?? Int.max
            let aca2Order = orderByKey[aca2.mainChainAsset.uniqueKey(accountId: accountIds.ca2AccountId)] ?? Int.max

            return aca1Order < aca2Order
        }

        func sortByDefaultList(
            aca1: AssetChainAssets,
            aca2: AssetChainAssets
        ) -> Bool {
            (
                aca1.totalFiatBalance,
                aca1.totalBalance,
                aca1.mainChainAsset.chain.isTestnet.invert().intValue,
                aca1.mainChainAsset.chain.isPolkadotOrKusama.intValue,
                aca1.mainChainAsset.chain.name,
                aca1.mainChainAsset.asset.name
            ) > (
                aca2.totalFiatBalance,
                aca2.totalBalance,
                aca2.mainChainAsset.chain.isTestnet.invert().intValue,
                aca2.mainChainAsset.chain.isPolkadotOrKusama.intValue,
                aca2.mainChainAsset.chain.name,
                aca2.mainChainAsset.asset.name
            )
        }

        var orderByKey: [String: Int]?

        if let sortedKeys = wallet.assetKeysOrder {
            orderByKey = [:]
            for (index, key) in sortedKeys.enumerated() {
                orderByKey?[key] = index
            }
        }
        let chainAssetsDivide = chainAssets.divide(predicate: {
            wallet.fetch(for: $0.mainChainAsset.chain.accountRequest())?.accountId != nil
        })
        let chainAssetsWithAccount: [AssetChainAssets] = chainAssetsDivide.slice
        let chainAssetsWithoutAccount: [AssetChainAssets] = chainAssetsDivide.remainder

        var chainAssetsSorted: [AssetChainAssets] = chainAssetsWithAccount.sorted(by: { aca1, aca2 in
            if let orderByKey = orderByKey {
                return sortByOrderKey(aca1: aca1, aca2: aca2, orderByKey: orderByKey)
            } else {
                return sortByDefaultList(aca1: aca1, aca2: aca2)
            }
        })

        chainAssetsSorted.append(contentsOf: chainAssetsWithoutAccount)

        return chainAssetsSorted.compactMap { $0.mainChainAsset }
    }

    func getTotalBalance(
        for chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        wallet: MetaAccountModel
    ) -> Decimal {
        chainAssets.compactMap { chainAsset -> Decimal in
            if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
               let accountInfo = accountInfos[chainAsset.uniqueKey(accountId: accountId)] {
                return getBalance(for: chainAsset, accountInfo: accountInfo)
            }

            return Decimal.zero
        }.reduce(0, +)
    }

    func getBalanceString(
        for chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        locale: Locale,
        wallet: MetaAccountModel
    ) -> String? {
        let totalAssetBalance = getTotalBalance(
            for: chainAssets,
            accountInfos: accountInfos,
            wallet: wallet
        )

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
            accountInfo.data.sendAvailable,
            precision: assetInfo.assetPrecision
        ) ?? 0

        return balance
    }

    func getTotalFiatBalance(
        for chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        priceData: PriceData?,
        wallet: MetaAccountModel
    ) -> Decimal {
        chainAssets.compactMap { chainAsset -> Decimal? in
            if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
               let accountInfo = accountInfos[chainAsset.uniqueKey(accountId: accountId)] {
                return getFiatBalance(
                    for: chainAsset,
                    accountInfo: accountInfo,
                    priceData: priceData
                )
            }

            return nil
        }.reduce(0, +)
    }

    func getFiatBalanceString(
        for chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        priceData: PriceData?,
        locale: Locale,
        currency: Currency,
        wallet: MetaAccountModel
    ) -> String? {
        let totalFiatBalance = getTotalFiatBalance(
            for: chainAssets,
            accountInfos: accountInfos,
            priceData: priceData,
            wallet: wallet
        )

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

    func sortChainAssets(
        ca1: ChainAsset,
        ca2: ChainAsset
    ) -> Bool {
        (
            ca1.chain.isTestnet.intValue,
            ca1.isParentChain().invert().intValue,
            ca1.isPolkadot(polkadotChainId).invert().intValue
        ) < (
            ca2.chain.isTestnet.intValue,
            ca2.isParentChain().invert().intValue,
            ca2.isPolkadot(polkadotChainId).invert().intValue
        )
    }

    func createAssetChainAssets(
        from chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        pricesData: [PriceData],
        wallet: MetaAccountModel
    ) -> [AssetChainAssets] {
        let assetNamesSet: Set<String> = Set(chainAssets.map { $0.asset.name })
        return assetNamesSet.compactMap { name in
            let assetChainAssets = chainAssets.filter { $0.asset.name == name }
            let chainAssetsSorted = assetChainAssets.sorted(by: { ca1, ca2 in
                sortChainAssets(ca1: ca1, ca2: ca2)
            })
            guard let mainChainAsset =
                chainAssetsSorted.first(where: { $0.isUtility }) ??
                chainAssetsSorted.first(where: { $0.isNative == true }) ??
                chainAssetsSorted.first else {
                return nil
            }
            let totalBalance = getTotalBalance(
                for: assetChainAssets,
                accountInfos: accountInfos,
                wallet: wallet
            )
            let priceId = mainChainAsset.asset.priceId ?? mainChainAsset.asset.id
            let priceData = pricesData.first(where: { $0.priceId == priceId })
            let totalFiatBalance = getTotalFiatBalance(
                for: assetChainAssets,
                accountInfos: accountInfos,
                priceData: priceData,
                wallet: wallet
            )
            let assetCA = AssetChainAssets(
                chainAssets: assetChainAssets,
                mainChainAsset: mainChainAsset,
                totalBalance: totalBalance,
                totalFiatBalance: totalFiatBalance
            )
            return assetCA
        }
    }

    func checkForHide(chainAsset: ChainAsset, wallet: MetaAccountModel) -> Bool {
        let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId

        if let assetIdsEnabled = wallet.assetIdsEnabled, let accountId = accountId {
            return assetIdsEnabled.contains { assetId in
                assetId == chainAsset.uniqueKey(accountId: accountId)
            }
        }
        return false
    }
}

extension ChainAssetListViewModelFactory: RemoteImageViewModelFactoryProtocol {}
extension ChainAssetListViewModelFactory: ChainOptionsViewModelFactoryProtocol {}

private extension ChainAsset {
    func isPolkadot(_ polkadotId: String?) -> Bool {
        chain.parentId == polkadotId || chain.chainId == polkadotId
    }

    func isParentChain() -> Bool {
        chain.parentId == nil
    }
}
