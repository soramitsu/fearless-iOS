import Foundation
import SoraFoundation
import SoraKeystore
import BigInt
import SSFModels

// swiftlint:disable function_parameter_count function_body_length
protocol ChainAssetListViewModelFactoryProtocol {
    func buildViewModel(
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset],
        locale: Locale,
        accountInfos: [ChainAssetKey: AccountInfo?],
        prices: PriceDataUpdated,
        chainsWithMissingAccounts: [ChainModel.Id],
        activeFilters: [ChainAssetsFetching.Filter]
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
        chainsWithMissingAccounts: [ChainModel.Id],
        activeFilters: [ChainAssetsFetching.Filter]
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

        let kusamaChainAssets = chainAssets.divide(predicate: { $0.defineEcosystem() == .kusama }).slice
        let polkadotChainAssets = chainAssets.divide(predicate: { $0.defineEcosystem() == .polkadot }).slice

        let kusamaAssetChainAssetsArray = createAssetChainAssets(
            from: kusamaChainAssets,
            accountInfos: accountInfos,
            pricesData: prices.pricesData,
            wallet: wallet
        )
        let polkadotAssetChainAssetsArray = createAssetChainAssets(
            from: polkadotChainAssets,
            accountInfos: accountInfos,
            pricesData: prices.pricesData,
            wallet: wallet
        )
        let assetChainAssetsArray = kusamaAssetChainAssetsArray + polkadotAssetChainAssetsArray

        let sortedAssetChainAssets = sortAssetList(
            wallet: wallet,
            assetChainAssetsArray: assetChainAssetsArray
        )

        let chainAssetCellModels: [ChainAccountBalanceCellViewModel] = sortedAssetChainAssets.compactMap { assetChainAssets in
            let priceId = assetChainAssets.mainChainAsset.asset.priceId ?? assetChainAssets.mainChainAsset.asset.id
            let priceData = prices.pricesData.first(where: { $0.priceId == priceId })

            return buildChainAccountBalanceCellViewModel(
                chainAssets: assetChainAssets.chainAssets,
                chainAsset: assetChainAssets.mainChainAsset,
                priceData: priceData,
                priceDataUpdated: prices.updated,
                accountInfos: accountInfos,
                locale: locale,
                currency: wallet.selectedCurrency,
                wallet: wallet,
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

        let shouldShowEmptyStatePerFilter = activeFilters.map {
            if case ChainAssetsFetching.Filter.search = $0 {
                return true
            }

            if case ChainAssetsFetching.Filter.searchEmpty = $0 {
                return false
            }

            return true
        }
        let emptyStateIsActive = activeSectionCellModels.isEmpty && hiddenSectionCellModels.isEmpty && shouldShowEmptyStatePerFilter.contains(where: { $0 == true })
        let bannerIsHidden = activeFilters.map {
            if case ChainAssetsFetching.Filter.search = $0 {
                return true
            }

            if case ChainAssetsFetching.Filter.searchEmpty = $0 {
                return true
            }

            return false
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
            hiddenSectionState: hiddenSectionState,
            emptyStateIsActive: emptyStateIsActive,
            bannerIsHidden: bannerIsHidden.contains(true)
        )
    }
}

private extension ChainAssetListViewModelFactory {
    func tokenFormatter(
        for currency: Currency,
        locale: Locale
    ) -> TokenFormatter {
        let displayInfo = AssetBalanceDisplayInfo.forCurrency(currency)
        let tokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: displayInfo, usageCase: .fiat)
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
        chainsWithMissingAccounts: [ChainModel.Id]
    ) -> ChainAccountBalanceCellViewModel? {
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
        let chainsAssetsWithBalance = chainAssets.filter { chainAsset in
            if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
               let accountInfo = accountInfos[chainAsset.uniqueKey(accountId: accountId)] {
                return getBalance(for: chainAsset, accountInfo: accountInfo) != Decimal.zero
            }
            return false
        }

        let notUtilityChainsWithBalance = chainsAssetsWithBalance.filter { $0 != chainAsset }
        let isMissingAccount = chainAssets.first(where: {
            chainsWithMissingAccounts.contains($0.chain.chainId)
                || wallet.unusedChainIds.or([]).contains($0.chain.chainId)
        }) != nil

        if
            chainsWithMissingAccounts.contains(chainAsset.chain.chainId)
            || wallet.unusedChainIds.or([]).contains(chainAsset.chain.chainId) {
            isColdBoot = !isMissingAccount
        }

        let totalAssetBalance = getBalanceString(
            for: chainAssets,
            accountInfos: accountInfos,
            locale: locale,
            wallet: wallet
        )

        let totalFiatBalance = getFiatBalanceString(
            for: chainAssets,
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

        let balance = getTotalBalance(
            for: chainAssets,
            accountInfos: accountInfos,
            wallet: wallet
        )

        let shownChainAssetsIconsArray = notUtilityChainsWithBalance.map { $0.chain.icon }
        var chainImages = Array(Set(shownChainAssetsIconsArray))
            .map { $0.map { RemoteImageViewModel(url: $0) }}
        if !shownChainAssetsIconsArray.contains(chainAsset.chain.icon) {
            let chainImageUrl = chainAsset.chain.icon.map { RemoteImageViewModel(url: $0) }
            chainImages.insert(chainImageUrl, at: 0)
        }

        let chainIconsViewModel = ChainCollectionViewModel(
            maxImagesCount: 5,
            chainImages: chainImages
        )

        let viewModel = ChainAccountBalanceCellViewModel(
            assetContainsChainAssets: chainAssets,
            chainIconViewViewModel: chainIconsViewModel,
            chainAsset: chainAsset,
            assetName: chainAsset.asset.name,
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
            isMissingAccount: isMissingAccount,
            isHidden: checkForHide(
                chainAsset: chainAsset,
                wallet: wallet,
                balance: balance,
                shouldHideZeroBalanceAssets: wallet.zeroBalanceAssetsHidden
            ),
            isUnused: isUnused,
            locale: locale
        )

        return viewModel
    }

    func sortAssetList(
        wallet: MetaAccountModel,
        assetChainAssetsArray: [AssetChainAssets]
    ) -> [AssetChainAssets] {
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
                aca1.mainChainAsset.asset.symbolUppercased
            ) > (
                aca2.totalFiatBalance,
                aca2.totalBalance,
                aca2.mainChainAsset.chain.isTestnet.invert().intValue,
                aca2.mainChainAsset.chain.isPolkadotOrKusama.intValue,
                aca2.mainChainAsset.chain.name,
                aca2.mainChainAsset.asset.symbolUppercased
            )
        }

        var orderByKey: [String: Int]?

        if let sortedKeys = wallet.assetKeysOrder {
            orderByKey = [:]
            for (index, key) in sortedKeys.enumerated() {
                orderByKey?[key] = index
            }
        }
        let chainAssetsDivide = assetChainAssetsArray.divide(predicate: {
            wallet.fetch(for: $0.mainChainAsset.chain.accountRequest())?.accountId != nil
        })
        let chainAssetsWithAccount: [AssetChainAssets] = chainAssetsDivide.slice
        let chainAssetsWithoutAccount: [AssetChainAssets] = chainAssetsDivide.remainder

        var assetChainAssetsSorted: [AssetChainAssets] = chainAssetsWithAccount.sorted(by: { aca1, aca2 in
            if let orderByKey = orderByKey {
                return sortByOrderKey(aca1: aca1, aca2: aca2, orderByKey: orderByKey)
            } else {
                return sortByDefaultList(aca1: aca1, aca2: aca2)
            }
        })

        assetChainAssetsSorted.append(contentsOf: chainAssetsWithoutAccount)

        return assetChainAssetsSorted
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

        let digits = totalAssetBalance > 0 ? 3 : 0
        return totalAssetBalance.toString(locale: locale, minimumDigits: digits, maximumDigits: digits)
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
            ca1.defineEcosystem().isKusama.intValue
        ) < (
            ca2.chain.isTestnet.intValue,
            ca2.isParentChain().invert().intValue,
            ca2.defineEcosystem().isKusama.intValue
        )
    }

    func createAssetChainAssets(
        from chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        pricesData: [PriceData],
        wallet: MetaAccountModel
    ) -> [AssetChainAssets] {
        let assetNamesSet: Set<String> = Set(chainAssets.map { $0.asset.symbolUppercased })

        return assetNamesSet.compactMap { name in
            let assetChainAssets = chainAssets.filter { $0.asset.symbolUppercased == name && wallet.fetch(for: $0.chain.accountRequest()) != nil }
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

    func checkForHide(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        balance: Decimal,
        shouldHideZeroBalanceAssets: Bool
    ) -> Bool {
        let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId

        if let accountId = accountId {
            let manuallyHidden = wallet.assetsVisibility.first(where: { assetVisibility in
                assetVisibility.assetId == chainAsset.uniqueKey(accountId: accountId)
            })?.hidden

            if let manuallyHidden = manuallyHidden {
                return manuallyHidden
            }
        }

        return shouldHideZeroBalanceAssets && balance == .zero
    }
}

extension ChainAssetListViewModelFactory: RemoteImageViewModelFactoryProtocol {}
extension ChainAssetListViewModelFactory: ChainOptionsViewModelFactoryProtocol {}

extension ChainAsset {
    func defineEcosystem() -> ChainEcosystem {
        if chain.parentId == Chain.polkadot.genesisHash || chain.chainId == Chain.polkadot.genesisHash {
            return .polkadot
        }
        return .kusama
    }

    func isParentChain() -> Bool {
        chain.parentId == nil
    }
}
