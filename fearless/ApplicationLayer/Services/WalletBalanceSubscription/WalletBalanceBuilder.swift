import Foundation

protocol WalletBalanceBuilderProtocol {
    func buildBalance(
        for accountInfos: [ChainAssetKey: AccountInfo?],
        _ metaAccounts: [MetaAccountModel],
        _ chainAssets: [ChainAsset],
        _ prices: [PriceData]
    ) -> [MetaAccountId: WalletBalance]?
}

final class WalletBalanceBuilder: WalletBalanceBuilderProtocol {
    func buildBalance(
        for accountInfos: [ChainAssetKey: AccountInfo?],
        _ metaAccounts: [MetaAccountModel],
        _ chainAssets: [ChainAsset],
        _ prices: [PriceData]
    ) -> [MetaAccountId: WalletBalance]? {
        let walletBalanceMap = metaAccounts.reduce(
            [MetaAccountId: WalletBalance]()
        ) { (result, account) -> [MetaAccountId: WalletBalance]? in

            let splitedChainAssets = split(chainAssets, for: account)
            let enabledChainAssets = splitedChainAssets.enabled
            let disabledChainAssets = splitedChainAssets.disabled

            let enabledAssetFiatBalanceInfo = countBalance(
                for: enabledChainAssets,
                account,
                accountInfos,
                prices
            )

            let disabledAssetFiatBalanceInfo = countBalance(
                for: disabledChainAssets,
                account,
                accountInfos,
                prices
            )

            let enabledAssetFiatBalance = enabledAssetFiatBalanceInfo.totalBalance
            let disabledAssetFiatBalance = disabledAssetFiatBalanceInfo.totalBalance
            let totalFiatValue = enabledAssetFiatBalance + disabledAssetFiatBalance

            let enabledTotalDayChange = enabledAssetFiatBalanceInfo.totalDayChange
            let disabledTotalDayChange = disabledAssetFiatBalanceInfo.totalDayChange
            let totalDayChange = enabledTotalDayChange + disabledTotalDayChange

            let dayChangePercent = (totalDayChange / totalFiatValue) * 100

            let isLoaded = enabledAssetFiatBalanceInfo.isLoaded && disabledAssetFiatBalanceInfo.isLoaded

            guard isLoaded else {
                return nil
            }

            let walletBalance = WalletBalance(
                totalFiatValue: totalFiatValue,
                enabledAssetFiatBalance: enabledAssetFiatBalance,
                dayChangePercent: dayChangePercent,
                dayChangeValue: totalDayChange,
                currency: account.selectedCurrency
            )

            var result = result
            result?[account.metaId] = walletBalance
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

        chainAssets.forEach { chainAsset in
            let accountRequest = chainAsset.chain.accountRequest()
            guard let accountId = metaAccount.fetch(for: accountRequest)?.accountId else {
                return
            }
            let chainAssetKey = chainAsset.uniqueKey(accountId: accountId)
            let accountInfo = accountInfos[chainAssetKey] ?? nil

            let balance = getFiatBalance(
                for: chainAsset,
                accountInfo,
                prices
            )

            if accountInfos.keys.contains(chainAssetKey) {
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
            let accountRequest = chainAsset.chain.accountRequest()
            guard let accountId = metaAccount.fetch(for: accountRequest)?.accountId else {
                return
            }
            let chainAssetKey = chainAsset.uniqueKey(accountId: accountId)

            if
                let assetIdsEnabled = metaAccount.assetIdsEnabled,
                assetIdsEnabled.contains(chainAssetKey) {
                enabledChainAssets.append(chainAsset)
            } else {
                disabledChainAssets.append(chainAsset)
            }
        }

        return (enabled: enabledChainAssets, disabled: disabledChainAssets)
    }

    private func getFiatBalance(
        for chainAsset: ChainAsset,
        _ accountInfo: AccountInfo?,
        _ prices: [PriceData]
    ) -> DayFiatBalance {
        let balanceDecimal = getBalance(
            for: chainAsset,
            accountInfo
        )

        guard let priceId = chainAsset.asset.priceId,
              let priceData = prices.first(where: { $0.priceId == priceId }),
              let priceDecimal = Decimal(string: priceData.price)
        else {
            return DayFiatBalance(total: .zero, dayChange: .zero)
        }

        let total = priceDecimal * balanceDecimal
        let dayChange = total * (priceData.fiatDayChange ?? .zero)
        let dayFiatBalance = DayFiatBalance(total: total, dayChange: dayChange)

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

private struct DayFiatBalance {
    let total: Decimal
    let dayChange: Decimal
}
