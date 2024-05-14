import Foundation
import SSFModels

protocol WalletBalanceBuilderProtocol {
    func buildBalance(
        for accountInfos: [ChainAssetKey: AccountInfo?],
        _ metaAccounts: [MetaAccountModel],
        _ chainAssets: [ChainAsset],
        _ prices: [PriceData]
    ) -> [MetaAccountId: WalletBalanceInfo]?
}

final class WalletBalanceBuilder: WalletBalanceBuilderProtocol {
    func buildBalance(
        for accountInfos: [ChainAssetKey: AccountInfo?],
        _ metaAccounts: [MetaAccountModel],
        _ chainAssets: [ChainAsset],
        _ prices: [PriceData]
    ) -> [MetaAccountId: WalletBalanceInfo]? {
        let walletBalanceMap = metaAccounts.reduce(
            [MetaAccountId: WalletBalanceInfo]()
        ) { (result, wallet) -> [MetaAccountId: WalletBalanceInfo]? in

            let splitedChainAssets = split(chainAssets, for: wallet)
            let enabledChainAssets = splitedChainAssets.enabled
            let disabledChainAssets = splitedChainAssets.disabled

            let enabledAssetFiatBalanceInfo = countBalance(
                for: enabledChainAssets,
                wallet,
                accountInfos,
                prices
            )

            let disabledAssetFiatBalanceInfo = countBalance(
                for: disabledChainAssets,
                wallet,
                accountInfos,
                prices
            )

            let enabledAssetFiatBalance = enabledAssetFiatBalanceInfo.totalBalance
            let disabledAssetFiatBalance = disabledAssetFiatBalanceInfo.totalBalance
            let totalFiatValue = enabledAssetFiatBalance + disabledAssetFiatBalance

            let enabledTotalDayChange = enabledAssetFiatBalanceInfo.totalDayChange
            let disabledTotalDayChange = disabledAssetFiatBalanceInfo.totalDayChange
            let totalDayChange = enabledTotalDayChange + disabledTotalDayChange

            let dayChangePercent = (totalDayChange / totalFiatValue)

            let isLoaded = enabledAssetFiatBalanceInfo.isLoaded && disabledAssetFiatBalanceInfo.isLoaded

            guard isLoaded else {
                return nil
            }

            let walletBalance = WalletBalanceInfo(
                totalFiatValue: totalFiatValue,
                enabledAssetFiatBalance: enabledAssetFiatBalance,
                dayChangePercent: dayChangePercent.isNaN ? .zero : dayChangePercent,
                dayChangeValue: totalDayChange,
                currency: wallet.selectedCurrency,
                prices: prices.filter { $0.currencyId == wallet.selectedCurrency.id },
                accountInfos: accountInfos
            )

            var result = result
            result?[wallet.metaId] = walletBalance
            return result
        }

        return walletBalanceMap
    }

    private func countBalance(
        for chainAssets: [ChainAsset],
        _ metaAccount: MetaAccountModel,
        _ accountInfos: [ChainAssetKey: AccountInfo?],
        _ prices: [PriceData]
    ) -> CountBalanceInfo {
        var accountInfosCount = 0
        var totalBalance: Decimal = .zero
        var totalDayChange: Decimal = .zero
        var enabledAccountInfos: [ChainAssetKey: AccountInfo?] = [:]

        chainAssets.forEach { chainAsset in
            let accountRequest = chainAsset.chain.accountRequest()
            guard let accountId = metaAccount.fetch(for: accountRequest)?.accountId else {
                return
            }
            let chainAssetKey = chainAsset.uniqueKey(accountId: accountId)
            let accountInfo = accountInfos[chainAssetKey] ?? nil
            enabledAccountInfos[chainAssetKey] = accountInfo

            let balance = getFiatBalance(
                for: chainAsset,
                accountInfo,
                prices,
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
        _ prices: [PriceData],
        currency: Currency
    ) -> AssetFiatBalanceInfo {
        let balanceDecimal = getBalance(
            for: chainAsset,
            accountInfo
        )

        guard let priceId = chainAsset.asset.priceId,
              let priceData = prices.first(where: { $0.priceId == priceId && $0.currencyId == currency.id }),
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
