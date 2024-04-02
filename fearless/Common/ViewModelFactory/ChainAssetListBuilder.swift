import Foundation
import SoraFoundation
import SSFModels

protocol ChainAssetListBuilder {
    var assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol { get }
}

struct AssetChainAssets {
    let chainAssets: [ChainAsset]
    let mainChainAsset: ChainAsset
    let totalBalance: Decimal
    let totalFiatBalance: Decimal
    let isVisible: Bool
}

extension ChainAssetListBuilder {
    func tokenFormatter(
        for currency: Currency,
        locale: Locale
    ) -> TokenFormatter {
        let displayInfo = AssetBalanceDisplayInfo.forCurrency(currency)
        let tokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: displayInfo, usageCase: .fiat)
        let tokenFormatterValue = tokenFormatter.value(for: locale)
        return tokenFormatterValue
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
        wallet: MetaAccountModel,
        shouldShowZero: Bool
    ) -> String? {
        let totalFiatBalance = getTotalFiatBalance(
            for: chainAssets,
            accountInfos: accountInfos,
            priceData: priceData,
            wallet: wallet
        )

        let balanceTokenFormatterValue = tokenFormatter(for: wallet.selectedCurrency, locale: locale)
        let stringFiatBalance = balanceTokenFormatterValue.stringFromDecimal(totalFiatBalance)

        if shouldShowZero, totalFiatBalance.isZero {
            return stringFiatBalance
        } else {
            return totalFiatBalance.isZero ? nil : stringFiatBalance
        }
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
                accountInfo.data.sendAvailable,
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
            ca1.defineEcosystem().isKusama.intValue,
            ca1.chain.chainId
        ) < (
            ca2.chain.isTestnet.intValue,
            ca2.isParentChain().invert().intValue,
            ca2.defineEcosystem().isKusama.intValue,
            ca2.chain.chainId
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
                chainAssetsSorted.first
            else {
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

            let enabledAssetIds = wallet.assetsVisibility
                .filter { !$0.hidden }
                .map { $0.assetId }
            let isVisible = enabledAssetIds.contains { enabledAssetId in
                assetChainAssets.contains(where: { $0.asset.id == enabledAssetId })
            }

            let assetCA = AssetChainAssets(
                chainAssets: assetChainAssets,
                mainChainAsset: mainChainAsset,
                totalBalance: totalBalance,
                totalFiatBalance: totalFiatBalance,
                isVisible: isVisible
            )
            return assetCA
        }
    }

    func enabled(
        chainAssets: [ChainAsset],
        for wallet: MetaAccountModel
    ) -> [ChainAsset] {
        guard wallet.assetsVisibility.isNotEmpty else {
            return defaultByPopular(chainAssets: chainAssets)
        }
        let enabledAssetIds = wallet.assetsVisibility
            .filter { !$0.hidden }
            .map { $0.assetId }
        let enabled = chainAssets.filter {
            enabledAssetIds.contains($0.asset.id)
        }
        return enabled
    }

    func defaultByPopular(chainAssets: [ChainAsset]) -> [ChainAsset] {
        chainAssets.filter { $0.chain.rank != nil && $0.asset.isUtility }
    }

    func filterChainAssets(
        with filter: NetworkManagmentFilter?,
        chainAssets: [ChainAsset],
        wallet: MetaAccountModel,
        search: String?
    ) -> [ChainAsset] {
        let byFilterChainAssets: [ChainAsset]
        switch filter {
        case let .chain(id):
            byFilterChainAssets = chainAssets.filter { $0.chain.chainId == id }
        case .all, .none:
            byFilterChainAssets = chainAssets
        case .popular:
            byFilterChainAssets = chainAssets.filter { $0.chain.rank != nil }
        case .favourite:
            byFilterChainAssets = chainAssets.filter { wallet.favouriteChainIds.contains($0.chain.chainId) }
        }

        guard let search, search.isNotEmpty else {
            return byFilterChainAssets
        }

        let bySearch = byFilterChainAssets.filter {
            $0.asset.symbol.lowercased().contains(search.lowercased()) || $0.asset.name.lowercased().contains(search.lowercased())
        }
        return bySearch
    }
}
