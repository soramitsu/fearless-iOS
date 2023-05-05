import Foundation
import SoraFoundation

// swiftlint:disable function_parameter_count
protocol BalanceBuilderProtocol {
    func buildBalance(
        chains: [ChainModel],
        accountInfos: [ChainModel.Id: AccountInfo],
        prices: [PriceData],
        metaAccount: MetaAccountModel,
        completion: @escaping (String?) -> Void
    )
    func buildBalance(
        for accounts: [ManagedMetaAccountModel],
        chains: [ChainModel],
        accountsInfos: [ChainAssetKey: AccountInfo],
        prices: [PriceData],
        completion: @escaping ([ManagedMetaAccountModel]) -> Void
    )
}

final class BalanceBuilder: BalanceBuilderProtocol {
    // MARK: - Private properties

    private lazy var assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
    private lazy var locale: Locale = {
        let localicationManaget = LocalizationManager.shared
        return localicationManaget.selectedLocale
    }()

    // MARK: - BalanceBuilder

    func buildBalance(
        chains: [ChainModel],
        accountInfos: [ChainModel.Id: AccountInfo],
        prices: [PriceData],
        metaAccount: MetaAccountModel,
        completion: @escaping (String?) -> Void
    ) {
        let balanceTokenFormatterValue = tokenFormatter(for: metaAccount.selectedCurrency)

        let chainAsset = chains.map(\.chainAssets).reduce([], +)
        let totalWalletBalance: Decimal = chainAsset.compactMap { chainAsset in
            guard let accountId = metaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return .zero
            }
            let accountInfo = accountInfos[chainAsset.uniqueKey(accountId: accountId)]

            return getBalance(
                for: chainAsset,
                accountInfo: accountInfo,
                prices: prices
            )
        }.reduce(0, +)

        let totalWalletBalanceString = balanceTokenFormatterValue.stringFromDecimal(totalWalletBalance)

        completion(totalWalletBalanceString)
    }

    func buildBalance(
        for managetMetaAccounts: [ManagedMetaAccountModel],
        chains: [ChainModel],
        accountsInfos: [ChainAssetKey: AccountInfo],
        prices: [PriceData],
        completion: @escaping ([ManagedMetaAccountModel]) -> Void
    ) {
        let managetMetaAccoutsWithBalance = managetMetaAccounts.map { managetMetaAccount -> ManagedMetaAccountModel in
            let metaAccount = managetMetaAccount.info
            let balanceTokenFormatterValue = tokenFormatter(for: metaAccount.selectedCurrency)

            let chainsAssets = chains.map(\.chainAssets).reduce([], +)
            let totalWalletBalance: Decimal = chainsAssets.map { chainAsset in

                guard let accountId = metaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                    return .zero
                }
                let accountInfo = accountsInfos[chainAsset.uniqueKey(accountId: accountId)]

                return getBalance(
                    for: chainAsset,
                    accountInfo: accountInfo,
                    prices: prices
                )
            }.reduce(0, +)

            let totalWalletBalanceString = balanceTokenFormatterValue.stringFromDecimal(totalWalletBalance)
            return ManagedMetaAccountModel(
                info: managetMetaAccount.info,
                isSelected: managetMetaAccount.isSelected,
                order: managetMetaAccount.order,
                balance: totalWalletBalanceString
            )
        }

        completion(managetMetaAccoutsWithBalance)
    }

    // MARK: - Private methods

    private func tokenFormatter(for currency: Currency) -> TokenFormatter {
        let balanceDisplayInfo = AssetBalanceDisplayInfo.forCurrency(currency)
        let balanceTokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: balanceDisplayInfo, usageCase: .fiat)
        let balanceTokenFormatterValue = balanceTokenFormatter.value(for: locale)
        return balanceTokenFormatterValue
    }

    private func getBalance(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?,
        prices: [PriceData]
    ) -> Decimal {
        let balanceDecimal = getBalance(
            for: chainAsset,
            accountInfo: accountInfo
        )

        guard let priceId = chainAsset.asset.priceId,
              let priceData = prices.first(where: { $0.priceId == priceId }),
              let priceDecimal = Decimal(string: priceData.price)
        else {
            return .zero
        }

        return priceDecimal * balanceDecimal
    }

    private func getBalance(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?
    ) -> Decimal {
        guard
            let accountInfo = accountInfo,
            let balance = Decimal.fromSubstrateAmount(
                accountInfo.data.total,
                precision: chainAsset.asset.displayInfo.assetPrecision
            )
        else {
            return Decimal.zero
        }

        return balance
    }
}
