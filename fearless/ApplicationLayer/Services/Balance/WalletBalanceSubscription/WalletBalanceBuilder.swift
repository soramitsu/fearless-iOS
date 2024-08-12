import Foundation
import SSFModels

protocol WalletBalanceBuilderProtocol {
    func buildBalance(
        for accountInfos: [ChainAssetKey: AccountInfo?],
        _ metaAccounts: [MetaAccountModel],
        _ chainAssets: [ChainAsset]
    ) -> [MetaAccountId: WalletBalanceInfo]?
}

final class WalletBalanceBuilder: WalletBalanceBuilderProtocol {
    func buildBalance(
        for accountInfos: [ChainAssetKey: AccountInfo?],
        _ metaAccounts: [MetaAccountModel],
        _ chainAssets: [ChainAsset]
    ) -> [MetaAccountId: WalletBalanceInfo]? {
        let walletBalanceMap = metaAccounts.reduce(
            [MetaAccountId: WalletBalanceInfo]()
        ) { (result, wallet) -> [MetaAccountId: WalletBalanceInfo]? in

            let splitedChainAssets = split(chainAssets, for: wallet)
            let enabledChainAssets = splitedChainAssets.enabled

            let enabledAssetFiatBalanceInfo = countBalance(
                for: enabledChainAssets,
                wallet,
                accountInfos
            )

            let enabledAssetFiatBalance = enabledAssetFiatBalanceInfo.totalBalance
            let totalFiatValue = enabledAssetFiatBalance
            let enabledTotalDayChange = enabledAssetFiatBalanceInfo.totalDayChange
            let totalDayChange = enabledTotalDayChange
            let dayChangePercent = (totalDayChange / totalFiatValue)
            let isLoaded = enabledAssetFiatBalanceInfo.isLoaded

            guard isLoaded else {
                return nil
            }

            let walletBalance = WalletBalanceInfo(
                totalFiatValue: totalFiatValue,
                enabledAssetFiatBalance: enabledAssetFiatBalance,
                dayChangePercent: dayChangePercent.isNaN ? .zero : dayChangePercent,
                dayChangeValue: totalDayChange,
                currency: wallet.selectedCurrency,
                prices: prices(for: wallet.selectedCurrency, from: chainAssets),
                accountInfos: accountInfos
            )

            var result = result
            result?[wallet.metaId] = walletBalance
            return result
        }

        return walletBalanceMap
    }
    
    private func prices(for currency: Currency, from chainAssets: [ChainAsset]) -> [PriceData] {
        let pricesForCurrency: [PriceData] = chainAssets.compactMap { chainAsset in
            chainAsset.asset.getPrice(for: currency)
        }
        return pricesForCurrency.uniq { $0.priceId }
    }

    private func countBalance(
        for chainAssets: [ChainAsset],
        _ metaAccount: MetaAccountModel,
        _ accountInfos: [ChainAssetKey: AccountInfo?]
    ) -> CountBalanceInfo {
        var accountInfosCount = 0
        var totalBalance: Decimal = .zero
        var totalDayChange: Decimal = .zero
        var enabledAccountInfos: [ChainAssetKey: AccountInfo?] = [:]

        chainAssets.forEach { chainAsset in
            let accountRequest = chainAsset.chain.accountRequest()
            guard let accountId = metaAccount.fetch(for: accountRequest)?.accountId else {
                accountInfosCount += 1
                return
            }
            let chainAssetKey = chainAsset.uniqueKey(accountId: accountId)
            let accountInfo = accountInfos[chainAssetKey] ?? nil
            enabledAccountInfos[chainAssetKey] = accountInfo

            let balance = getFiatBalance(
                for: chainAsset,
                accountInfo,
                currency: metaAccount.selectedCurrency
            )

            if enabledAccountInfos.keys.contains(chainAssetKey) {
                accountInfosCount += 1
            }

            totalBalance += balance.total
            totalDayChange += balance.dayChange
        }

        let isLoaded = accountInfosCount == chainAssets.count
        return CountBalanceInfo(
            totalBalance: totalBalance,
            totalDayChange: totalDayChange,
            isLoaded: isLoaded
        )
    }

    private func split(
        _ chainAssets: [ChainAsset],
        for metaAccount: MetaAccountModel
    ) -> (enabled: [ChainAsset], disabled: [ChainAsset]) {
        var enabledChainAssets: [ChainAsset] = []
        var disabledChainAssets: [ChainAsset] = []

        chainAssets.forEach { chainAsset in
            let assetsVisibility = metaAccount.assetsVisibility
            if assetsVisibility.first(where: { $0.assetId == chainAsset.identifier })?.hidden == true {
                disabledChainAssets.append(chainAsset)
            } else {
                enabledChainAssets.append(chainAsset)
            }
        }

        return (enabled: enabledChainAssets, disabled: disabledChainAssets)
    }

    private func getFiatBalance(
        for chainAsset: ChainAsset,
        _ accountInfo: AccountInfo?,
        currency: Currency
    ) -> AssetFiatBalanceInfo {
        let balanceDecimal = getBalance(
            for: chainAsset,
            accountInfo
        )

        guard let priceData = chainAsset.asset.getPrice(for: currency),
              let priceDecimal = Decimal(string: priceData.price)
        else {
            return AssetFiatBalanceInfo(total: .zero, dayChange: .zero)
        }

        let total = priceDecimal * balanceDecimal
        let dayChange = total * (priceData.fiatDayChange ?? .zero) / 100
        let dayFiatBalance = AssetFiatBalanceInfo(total: total, dayChange: dayChange)

        return dayFiatBalance
    }

    private func getBalance(
        for chainAsset: ChainAsset,
        _ accountInfo: AccountInfo?
    ) -> Decimal {
        guard
            let accountInfo = accountInfo,
            let balance = Decimal.fromSubstrateAmount(
                accountInfo.data.total,
                precision: chainAsset.asset.displayInfo.assetPrecision
            )
        else {
            return .zero
        }

        return balance
    }
}

private struct CountBalanceInfo {
    let totalBalance: Decimal
    let totalDayChange: Decimal
    let isLoaded: Bool
}

private struct AssetFiatBalanceInfo {
    let total: Decimal
    let dayChange: Decimal
}
