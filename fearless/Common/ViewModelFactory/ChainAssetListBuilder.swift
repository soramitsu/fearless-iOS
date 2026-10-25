import Foundation
import SoraFoundation
import SSFModels

protocol ChainAssetListBuilder {
    var assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol { get }
}

extension ChainAssetListBuilder {
    var assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol {
        AssetBalanceFormatterFactory()
    }
}

struct AssetChainAssets {
    let chainAssets: [ChainAsset]
    let mainChainAsset: ChainAsset
    let totalBalance: Decimal
    let totalFiatBalance: Decimal
    let isVisible: Bool
}

/// How one holding counts in the portfolio value (root `docs/portfolio-contract.md` §3). The
/// header, the network subtotals and the rows use the same roles, so rows add up to the header.
enum PortfolioValueRole: Equatable {
    /// Counted in the header total, its network subtotal and its row.
    case counted
    /// The user hid it: left out of the header and subtotals and labelled
    /// "N hidden assets not included". Wallet management still counts it ("incl. hidden").
    case hidden
    /// No trusted price: it adds no fiat and is labelled "N assets without price not included".
    case unpriced
    /// Test tokens have no value and are never counted, hidden or not.
    case testnet
    /// Detected, unverified metadata: never counted.
    case unverified
}

/// One asset of one wallet, valued by the portfolio definition.
struct PortfolioHoldingValue: Equatable {
    let role: PortfolioValueRole
    /// The total balance, free + reserved: staked, locked and reserved funds included.
    let amount: Decimal
    /// What can be sent now, free − frozen. Rows show it beside the total when it differs.
    let transferable: Decimal
    /// `amount` × the asset's own trusted price; zero without one.
    let fiat: Decimal
    let dayChange: Decimal

    var isFunded: Bool {
        amount > .zero
    }
}

/// What the portfolio total leaves out, for the captions under the list and the
/// "incl. hidden" wallet cards.
struct PortfolioExclusions: Equatable {
    /// Hidden assets that hold a balance.
    var hiddenCount = 0
    var hiddenFundedAssetKeys: [AssetKey] = []
    /// The trusted fiat value of those hidden balances and its 24h change.
    var hiddenFiat: Decimal = .zero
    var hiddenDayChange: Decimal = .zero
    /// Funded assets on test networks, hidden or not: test tokens have no value.
    var testnetCount = 0
    /// Funded assets that add no fiat because they have no trusted price.
    var unpricedCount = 0
    /// A counted native holding sits on a network with nomination pools. Pool stakes
    /// are outside free + reserved, so the total does not include them.
    var poolStakesExcluded = false

    var isEmpty: Bool {
        hiddenCount == 0 && testnetCount == 0 && unpricedCount == 0 && !poolStakesExcluded
    }
}

/// The portfolio value of one wallet over a set of assets.
struct PortfolioTotals: Equatable {
    /// The portfolio total: neither hidden, nor on a testnet, nor without a trusted price.
    var fiat: Decimal = .zero
    var dayChange: Decimal = .zero
    var exclusions = PortfolioExclusions()

    /// Every valued holding, hidden ones included: wallet management, backup and delete
    /// show it, so a wallet whose funds are all hidden never looks empty (critique D-12).
    var allHoldingsFiat: Decimal {
        fiat + exclusions.hiddenFiat
    }

    var allHoldingsDayChange: Decimal {
        dayChange + exclusions.hiddenDayChange
    }

    mutating func add(_ value: PortfolioHoldingValue, of chainAsset: ChainAsset) {
        guard value.isFunded else {
            return
        }

        switch value.role {
        case .counted:
            fiat += value.fiat
            dayChange += value.dayChange
            let isNative = chainAsset.asset.isUtility || chainAsset.asset.isNative
            if isNative, chainAsset.chain.options?.contains(.poolStaking) == true {
                exclusions.poolStakesExcluded = true
            }
        case .hidden:
            exclusions.hiddenCount += 1
            if !exclusions.hiddenFundedAssetKeys.contains(chainAsset.assetKey) {
                exclusions.hiddenFundedAssetKeys.append(chainAsset.assetKey)
            }
            exclusions.hiddenFiat += value.fiat
            exclusions.hiddenDayChange += value.dayChange
        case .unpriced:
            exclusions.unpricedCount += 1
        case .testnet:
            exclusions.testnetCount += 1
        case .unverified:
            break
        }
    }
}

extension ChainAssetListBuilder {
    func fiatFormatter(
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
                aca1.mainChainAsset.chain.isTestnet.inverted().intValue,
                aca1.mainChainAsset.chain.isPolkadotOrKusama.intValue,
                aca1.mainChainAsset.chain.name,
                aca1.mainChainAsset.asset.symbolUppercased
            ) > (
                aca2.totalFiatBalance,
                aca2.totalBalance,
                aca2.mainChainAsset.chain.isTestnet.inverted().intValue,
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
        wallet: MetaAccountModel
    ) -> Decimal {
        chainAssets.compactMap { chainAsset -> Decimal? in
            guard AssetTrustResolver.priceTrust(
                for: chainAsset,
                currency: wallet.selectedCurrency
            ).contributesToPortfolioTotal,
                let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
                let accountInfo = accountInfos[chainAsset.uniqueKey(accountId: accountId)] else {
                return nil
            }

            return getFiatBalance(
                for: chainAsset,
                accountInfo: accountInfo,
                priceData: chainAsset.asset.getPrice(for: wallet.selectedCurrency)
            )
        }.reduce(0, +)
    }

    func getFiatBalanceString(
        for chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        locale: Locale,
        wallet: MetaAccountModel,
        shouldShowZero: Bool
    ) -> String? {
        let totalFiatBalance = getTotalFiatBalance(
            for: chainAssets,
            accountInfos: accountInfos,
            wallet: wallet
        )

        let balanceTokenFormatterValue = fiatFormatter(for: wallet.selectedCurrency, locale: locale)
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

    // MARK: - Portfolio value

    // The functions above value the transferable amount and stay as they are for Send,
    // the asset pickers and AssetNetworks. The portfolio (rows, subtotals, header) values
    // the total balance with the functions below.

    /// The total balance, free + reserved.
    func getPortfolioBalance(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?
    ) -> Decimal {
        guard let accountInfo else {
            return .zero
        }

        return Decimal.fromSubstrateAmount(
            accountInfo.data.total,
            precision: chainAsset.asset.displayInfo.assetPrecision
        ) ?? .zero
    }

    /// The total balance times `priceData`; zero without a price.
    func getPortfolioFiatBalance(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?,
        priceData: PriceData?
    ) -> Decimal {
        guard let price = priceData?.price,
              let priceDecimal = Decimal(string: price) else {
            return .zero
        }

        return priceDecimal * getPortfolioBalance(for: chainAsset, accountInfo: accountInfo)
    }

    func portfolioValueRole(
        for chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        testnets: PortfolioTestnetChainList = .bundled,
        userDefaults: UserDefaults = .standard
    ) -> PortfolioValueRole {
        if testnets.isTestnet(chainAsset.chain) {
            return .testnet
        }

        guard AssetTrustResolver.metadataTrust(for: chainAsset, userDefaults: userDefaults).trust == .verified else {
            return .unverified
        }

        let preference = AssetVisibilityPreferenceStore.preference(
            walletId: wallet.metaId,
            assetKey: chainAsset.assetKey,
            userDefaults: userDefaults
        )
        if preference == .hidden {
            return .hidden
        }

        return AssetTrustResolver.priceTrust(
            for: chainAsset,
            currency: wallet.selectedCurrency
        ).contributesToPortfolioTotal ? .counted : .unpriced
    }

    func portfolioValue(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?,
        wallet: MetaAccountModel,
        testnets: PortfolioTestnetChainList = .bundled,
        userDefaults: UserDefaults = .standard
    ) -> PortfolioHoldingValue {
        let role = portfolioValueRole(
            for: chainAsset,
            wallet: wallet,
            testnets: testnets,
            userDefaults: userDefaults
        )
        let amount = getPortfolioBalance(for: chainAsset, accountInfo: accountInfo)
        let transferable = getBalance(for: chainAsset, accountInfo: accountInfo)

        // Hidden holdings keep their value for wallet management; testnet, unverified
        // and unpriced holdings have none.
        let priceData: PriceData?
        switch role {
        case .counted, .hidden:
            priceData = AssetTrustResolver.trustedPrice(for: chainAsset, currency: wallet.selectedCurrency)
        case .unpriced, .testnet, .unverified:
            priceData = nil
        }
        let fiat = getPortfolioFiatBalance(for: chainAsset, accountInfo: accountInfo, priceData: priceData)

        return PortfolioHoldingValue(
            role: role,
            amount: amount,
            transferable: transferable,
            fiat: fiat,
            dayChange: fiat * (priceData?.fiatDayChange ?? .zero) / 100
        )
    }

    /// The portfolio value of `wallet` over `chainAssets`. Assets without a balance add
    /// nothing, so they are not classified.
    func portfolioTotals(
        for chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        wallet: MetaAccountModel,
        testnets: PortfolioTestnetChainList = .bundled,
        userDefaults: UserDefaults = .standard
    ) -> PortfolioTotals {
        var totals = PortfolioTotals()

        for chainAsset in chainAssets {
            guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
                  let accountInfo = accountInfos[chainAsset.uniqueKey(accountId: accountId)] ?? nil,
                  accountInfo.data.total > 0 else {
                continue
            }

            totals.add(
                portfolioValue(
                    for: chainAsset,
                    accountInfo: accountInfo,
                    wallet: wallet,
                    testnets: testnets,
                    userDefaults: userDefaults
                ),
                of: chainAsset
            )
        }

        return totals
    }

    /// Hidden assets that hold a balance and their trusted fiat value, for the
    /// "N hidden assets not included" caption.
    func hiddenSummary(
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?]
    ) -> (count: Int, fiat: Decimal) {
        let exclusions = portfolioTotals(
            for: chainAssets,
            accountInfos: accountInfos,
            wallet: wallet
        ).exclusions

        return (count: exclusions.hiddenCount, fiat: exclusions.hiddenFiat)
    }

    func getPriceAttributedString(
        priceData: PriceData?,
        locale: Locale,
        currency: Currency
    ) -> NSAttributedString? {
        let balanceTokenFormatterValue = fiatFormatter(for: currency, locale: locale)

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
            ca1.isParentChain().inverted().intValue,
            ca1.defineEcosystem().isKusama.intValue,
            ca1.chain.chainId
        ) < (
            ca2.chain.isTestnet.intValue,
            ca2.isParentChain().inverted().intValue,
            ca2.defineEcosystem().isKusama.intValue,
            ca2.chain.chainId
        )
    }

    func createAssetChainAssets(
        from chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        wallet: MetaAccountModel
    ) -> [AssetChainAssets] {
        let accountAssets = chainAssets.filter {
            wallet.fetch(for: $0.chain.accountRequest()) != nil
        }
        let canonicalAssets = Dictionary(grouping: accountAssets, by: \.assetKey)
            .compactMap { _, matches in
                matches.sorted { $0.identifier < $1.identifier }.first
            }

        return canonicalAssets.map { mainChainAsset in
            let assetChainAssets = [mainChainAsset]
            let totalBalance = getTotalBalance(
                for: assetChainAssets,
                accountInfos: accountInfos,
                wallet: wallet
            )
            let totalFiatBalance = getTotalFiatBalance(
                for: assetChainAssets,
                accountInfos: accountInfos,
                wallet: wallet
            )

            let isVisible = AssetVisibilityPreferenceStore.preference(
                walletId: wallet.metaId,
                assetKey: mainChainAsset.assetKey
            ) == .shown

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

    func enabledOrDefault(
        chainAssets: [ChainAsset],
        for wallet: MetaAccountModel
    ) -> [ChainAsset] {
        let enabled = enabled(chainAssets: chainAssets, for: wallet)
        return enabled.isEmpty ? defaultByPopular(chainAssets: chainAssets) : enabled
    }

    func enabled(
        chainAssets: [ChainAsset],
        for wallet: MetaAccountModel
    ) -> [ChainAsset] {
        let enabled = chainAssets.filter { chainAsset in
            AssetVisibilityPreferenceStore.isSelectable(
                walletId: wallet.metaId,
                chainAsset: chainAsset
            )
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
            byFilterChainAssets = chainAssets.filter { $0.chain.rank != nil && !PortfolioTestnetChainList.bundled.isTestnet($0.chain) }
        case .favourite:
            byFilterChainAssets = chainAssets.filter { wallet.favouriteChainIds.contains($0.chain.chainId) }
        }

        guard let search, search.isNotEmpty else {
            return byFilterChainAssets
        }

        let bySearch = byFilterChainAssets.filter {
            [$0.asset.symbol, $0.asset.name, $0.chain.name].contains {
                $0.range(of: search, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
        return bySearch
    }

    func checkHasIssue(
        chain: ChainModel,
        wallet: MetaAccountModel,
        chainsWithIssue: [ChainIssue],
        chainSettings: [ChainSettings]
    ) -> (hasNetworkIssue: Bool, hasAccountIssue: Bool) {
        var hasNetworkIssues: Bool = false
        var hasMissingAccount: Bool = false
        chainsWithIssue.forEach { issue in
            switch issue {
            case let .network(chains):
                let mutedIssuesChainIds = chainSettings.filter { $0.issueMuted }.map { $0.chainId }
                hasNetworkIssues = chains.first(where: { !mutedIssuesChainIds.contains($0.chainId) && $0.chainId == chain.chainId }) != nil
            case let .missingAccount(chains):
                let unusedChains = wallet.unusedChainIds ?? []
                hasMissingAccount = chains.first(where: { !unusedChains.contains($0.chainId) && $0.chainId == chain.chainId }) != nil
            }
        }

        return (hasNetworkIssues, hasMissingAccount)
    }
}
