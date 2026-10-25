import Foundation
import SSFModels

protocol WalletBalanceBuilderProtocol {
    func buildBalance(
        for accountInfos: [ChainAssetKey: AccountInfo?],
        _ metaAccounts: [MetaAccountModel],
        _ chainAssets: [ChainAsset]
    ) -> [MetaAccountId: WalletBalanceInfo]?
}

/// Values wallets by the portfolio contract (root `docs/portfolio-contract.md` §3): the total
/// balance (free + reserved) times each asset's own trusted price. Hidden, testnet, unverified and
/// unpriced holdings stay out of the portfolio total and are reported in `exclusions`; hidden ones
/// still count in `totalFiatValue` for wallet management.
final class WalletBalanceBuilder: WalletBalanceBuilderProtocol, ChainAssetListBuilder {
    private let testnets: PortfolioTestnetChainList
    private let userDefaults: UserDefaults

    init(
        testnets: PortfolioTestnetChainList = .bundled,
        userDefaults: UserDefaults = .standard
    ) {
        self.testnets = testnets
        self.userDefaults = userDefaults
    }

    func buildBalance(
        for accountInfos: [ChainAssetKey: AccountInfo?],
        _ metaAccounts: [MetaAccountModel],
        _ chainAssets: [ChainAsset]
    ) -> [MetaAccountId: WalletBalanceInfo]? {
        let resolvedAccountInfos = mergingRemoteLastKnownBalances(
            into: accountInfos,
            wallets: metaAccounts,
            chainAssets: chainAssets
        )
        let walletBalanceMap = metaAccounts.reduce(
            [MetaAccountId: WalletBalanceInfo]()
        ) { (result, wallet) -> [MetaAccountId: WalletBalanceInfo]? in

            let balanceInfo = countBalance(
                for: chainAssets,
                wallet,
                resolvedAccountInfos
            )

            guard balanceInfo.isLoaded else {
                return nil
            }

            let totals = balanceInfo.totals
            let walletBalance = WalletBalanceInfo(
                totalFiatValue: totals.allHoldingsFiat,
                enabledAssetFiatBalance: totals.fiat,
                dayChangePercent: Self.dayChangePercent(totals.dayChange, of: totals.fiat),
                dayChangeValue: totals.dayChange,
                totalDayChangePercent: Self.dayChangePercent(totals.allHoldingsDayChange, of: totals.allHoldingsFiat),
                totalDayChangeValue: totals.allHoldingsDayChange,
                currency: wallet.selectedCurrency,
                prices: PriceDataHelper.prices(for: wallet.selectedCurrency, from: chainAssets),
                accountInfos: resolvedAccountInfos,
                exclusions: totals.exclusions
            )

            var result = result
            result?[wallet.metaId] = walletBalance
            return result
        }

        return walletBalanceMap
    }

    /// The portfolio header of `wallet`: the wallet-wide total in every lens and under every
    /// network filter (critique C4), plus the filtered networks' part for
    /// "Showing {network} · {amount}".
    func buildPortfolioHeaderBalance(
        for accountInfos: [ChainAssetKey: AccountInfo?],
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset]
    ) -> [MetaAccountId: WalletBalanceInfo]? {
        guard var balances = buildBalance(for: accountInfos, [wallet], chainAssets) else {
            return nil
        }

        let filter = NetworkManagmentFilter(identifier: wallet.networkManagmentFilter)
        if case .all = filter {
            return balances
        }

        let filteredChainAssets = filterChainAssets(
            with: filter,
            chainAssets: chainAssets,
            wallet: wallet,
            search: nil
        )
        let filteredFiat = buildBalance(
            for: accountInfos,
            [wallet],
            filteredChainAssets
        )?[wallet.metaId]?.enabledAssetFiatBalance ?? .zero

        let networkName: String?
        if case let .chain(chainId) = filter {
            networkName = chainAssets.first { $0.chain.chainId == chainId }?.chain.name
        } else {
            networkName = nil
        }
        balances[wallet.metaId]?.filteredPart = WalletBalanceFilteredPart(
            filter: filter,
            networkName: networkName,
            fiatBalance: filteredFiat
        )

        return balances
    }

    private static func dayChangePercent(_ dayChange: Decimal, of fiat: Decimal) -> Decimal {
        let percent = dayChange / fiat
        return percent.isNaN ? .zero : percent
    }

    private func mergingRemoteLastKnownBalances(
        into accountInfos: [ChainAssetKey: AccountInfo?],
        wallets: [MetaAccountModel],
        chainAssets: [ChainAsset]
    ) -> [ChainAssetKey: AccountInfo?] {
        var result = accountInfos

        wallets.forEach { wallet in
            chainAssets.forEach { chainAsset in
                guard
                    UniversalWalletChainAccountSupport.isUniversalWalletChain(
                        chainAsset.chain.chainId
                    ),
                    let accountId = wallet.fetch(
                        for: chainAsset.chain.accountRequest()
                    )?.accountId,
                    let wrapped = RemoteLastKnownBalanceStore.load(
                        chain: chainAsset.chain,
                        walletId: wallet.metaId
                    )[chainAsset.chainAssetId],
                    let accountInfo = wrapped
                else {
                    return
                }

                result[chainAsset.uniqueKey(accountId: accountId)] = accountInfo
            }
        }

        return result
    }

    private func countBalance(
        for chainAssets: [ChainAsset],
        _ metaAccount: MetaAccountModel,
        _ accountInfos: [ChainAssetKey: AccountInfo?]
    ) -> CountBalanceInfo {
        var accountInfosCount = 0
        var enabledAccountInfos: [ChainAssetKey: AccountInfo?] = [:]

        chainAssets.forEach { chainAsset in
            let accountRequest = chainAsset.chain.accountRequest()
            guard let accountId = metaAccount.fetch(for: accountRequest)?.accountId else {
                accountInfosCount += 1
                return
            }
            let chainAssetKey = chainAsset.uniqueKey(accountId: accountId)
            // `?? nil` flattens the lookup, so the key is stored whether or not the
            // network has answered: as in 4.0.4, an asset that was never looked up
            // (hidden, on a network that never answers, or counted) cannot hold the
            // total back.
            let accountInfo = accountInfos[chainAssetKey] ?? nil
            enabledAccountInfos[chainAssetKey] = accountInfo

            if enabledAccountInfos.keys.contains(chainAssetKey) {
                accountInfosCount += 1
            }
        }

        let totals = portfolioTotals(
            for: chainAssets,
            accountInfos: accountInfos,
            wallet: metaAccount,
            testnets: testnets,
            userDefaults: userDefaults
        )

        return CountBalanceInfo(
            totals: totals,
            isLoaded: accountInfosCount == chainAssets.count
        )
    }
}

private struct CountBalanceInfo {
    let totals: PortfolioTotals
    let isLoaded: Bool
}
