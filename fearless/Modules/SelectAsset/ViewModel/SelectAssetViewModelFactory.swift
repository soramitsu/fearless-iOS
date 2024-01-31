import Foundation
import SoraFoundation
import SSFModels

final class SelectAssetCellViewModel: SelectableViewModelProtocol {
    let name: String
    let symbol: String
    let icon: ImageViewModelProtocol?
    let balanceString: String?
    let fiatBalanceString: String?
    let isSelected: Bool

    let balanceDecimal: Decimal?
    let fiatBalanceDecimal: Decimal?

    init(
        name: String,
        symbol: String,
        icon: ImageViewModelProtocol?,
        balanceString: String?,
        fiatBalanceString: String?,
        isSelected: Bool,
        balanceDecimal: Decimal?,
        fiatBalanceDecimal: Decimal?
    ) {
        self.name = name
        self.symbol = symbol
        self.icon = icon
        self.balanceString = balanceString
        self.fiatBalanceString = fiatBalanceString
        self.isSelected = isSelected
        self.balanceDecimal = balanceDecimal
        self.fiatBalanceDecimal = fiatBalanceDecimal
    }
}

protocol SelectAssetViewModelFactoryProtocol {
    func buildViewModel(
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        prices: PriceDataUpdated,
        locale: Locale,
        selectedAssetId: String?
    ) -> [SelectAssetCellViewModel]
}

final class SelectAssetViewModelFactory: SelectAssetViewModelFactoryProtocol {
    private let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }

    func buildViewModel(
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        prices: PriceDataUpdated,
        locale: Locale,
        selectedAssetId: String?
    ) -> [SelectAssetCellViewModel] {
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

        let selectAssetCellModels: [SelectAssetCellViewModel] = chainAssets.compactMap { chainAsset in
            let priceId = chainAsset.asset.priceId ?? chainAsset.asset.id
            let priceData = prices.pricesData.first(where: { $0.priceId == priceId })

            return buildSelectAssetCellViewModel(
                chainAsset: chainAsset,
                priceData: priceData,
                accountInfos: accountInfos,
                currency: wallet.selectedCurrency,
                wallet: wallet,
                locale: locale,
                selectedAssetId: selectedAssetId
            )
        }

        let sortedList = selectAssetCellModels.sorted { viewModel1, viewModel2 in
            (
                viewModel1.fiatBalanceDecimal.or(.zero),
                viewModel1.balanceDecimal.or(.zero),
                viewModel2.symbol
            ) > (
                viewModel2.fiatBalanceDecimal.or(.zero),
                viewModel2.balanceDecimal.or(.zero),
                viewModel1.symbol
            )
        }

        return sortedList
    }
}

private extension SelectAssetViewModelFactory {
    func buildSelectAssetCellViewModel(
        chainAsset: ChainAsset,
        priceData: PriceData?,
        accountInfos: [ChainAssetKey: AccountInfo?],
        currency: Currency,
        wallet: MetaAccountModel,
        locale: Locale,
        selectedAssetId: String?
    ) -> SelectAssetCellViewModel {
        let totalAssetBalance = getBalanceString(
            for: chainAsset,
            accountInfos: accountInfos,
            locale: locale,
            wallet: wallet
        )

        let totalFiatBalance = getFiatBalanceString(
            for: chainAsset,
            accountInfos: accountInfos,
            priceData: priceData,
            locale: locale,
            currency: currency,
            wallet: wallet
        )

        return SelectAssetCellViewModel(
            name: chainAsset.chain.name,
            symbol: chainAsset.asset.symbolUppercased,
            icon: chainAsset.asset.icon.map { RemoteImageViewModel(url: $0) },
            balanceString: totalAssetBalance.0,
            fiatBalanceString: totalFiatBalance?.0,
            isSelected: chainAsset.asset.id == selectedAssetId,
            balanceDecimal: totalAssetBalance.1,
            fiatBalanceDecimal: totalFiatBalance?.1
        )
    }

    func getBalanceString(
        for chainAsset: ChainAsset,
        accountInfos: [ChainAssetKey: AccountInfo?],
        locale: Locale,
        wallet: MetaAccountModel
    ) -> (String?, Decimal) {
        var totalAssetBalance: Decimal = .zero
        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
           let accountInfo = accountInfos[chainAsset.uniqueKey(accountId: accountId)] {
            totalAssetBalance = getBalance(for: chainAsset, accountInfo: accountInfo)
        }

        let minDigits = totalAssetBalance > 0 ? 3 : 0
        let maxDigits = totalAssetBalance > 0 ? 8 : 0
        return (totalAssetBalance.toString(locale: locale, minimumDigits: minDigits, maximumDigits: maxDigits), totalAssetBalance)
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

    func getFiatBalanceString(
        for chainAsset: ChainAsset,
        accountInfos: [ChainAssetKey: AccountInfo?],
        priceData: PriceData?,
        locale: Locale,
        currency: Currency,
        wallet: MetaAccountModel
    ) -> (String?, Decimal)? {
        var totalFiatBalance: Decimal = .zero
        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
           let accountInfo = accountInfos[chainAsset.uniqueKey(accountId: accountId)] {
            totalFiatBalance = getFiatBalance(
                for: chainAsset,
                accountInfo: accountInfo,
                priceData: priceData
            )
        }

        guard totalFiatBalance != .zero else { return nil }

        let balanceTokenFormatterValue = tokenFormatter(for: currency, locale: locale)
        return (balanceTokenFormatterValue.stringFromDecimal(totalFiatBalance), totalFiatBalance)
    }

    func tokenFormatter(
        for currency: Currency,
        locale: Locale
    ) -> TokenFormatter {
        let displayInfo = AssetBalanceDisplayInfo.forCurrency(currency)
        let tokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: displayInfo, usageCase: .listCrypto)
        let tokenFormatterValue = tokenFormatter.value(for: locale)
        return tokenFormatterValue
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
}
