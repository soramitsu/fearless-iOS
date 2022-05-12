import Foundation
import SoraFoundation

// swiftlint:disable function_parameter_count
protocol BalanceBuilderProtocol {
    func buildBalance(
        chains: [ChainModel],
        accountInfos: [ChainModel.Id: AccountInfo],
        prices: [AssetModel.PriceId: PriceData],
        currency: Currency,
        completion: @escaping (String?) -> Void
    )
    func buildBalance(
        for accounts: [ManagedMetaAccountModel],
        chains: [ChainModel],
        accountsInfos: [String: [ChainModel.Id: AccountInfo]],
        prices: [AssetModel.PriceId: PriceData],
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
        prices: [AssetModel.PriceId: PriceData],
        currency: Currency,
        completion: @escaping (String?) -> Void
    ) {
        let balanceTokenFormatterValue = tokenFormatter(for: currency)

        let totalWalletBalance: Decimal = chains.compactMap { chainModel in
            let accountInfo = accountInfos[chainModel.chainId]

            return getBalance(
                for: chainModel,
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
        accountsInfos: [String: [ChainModel.Id: AccountInfo]],
        prices: [AssetModel.PriceId: PriceData],
        completion: @escaping ([ManagedMetaAccountModel]) -> Void
    ) {
        let managetMetaAccoutsWithBalance = managetMetaAccounts.map { managetMetaAccount -> ManagedMetaAccountModel in
            let metaAccount = managetMetaAccount.info
            let balanceTokenFormatterValue = tokenFormatter(for: metaAccount.selectedCurrency)

            let totalWalletBalance: Decimal = chains.compactMap { chainModel in

                guard let accountId = metaAccount.fetch(for: chainModel.accountRequest())?.accountId else {
                    return .zero
                }
                let key = accountId.toHex() + chainModel.chainId
                let accountInfo = accountsInfos[key]?[chainModel.chainId]

                return getBalance(
                    for: chainModel,
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
        let balanceTokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: balanceDisplayInfo)
        let balanceTokenFormatterValue = balanceTokenFormatter.value(for: locale)
        return balanceTokenFormatterValue
    }

    private func getBalance(
        for chainModel: ChainModel,
        accountInfo: AccountInfo?,
        prices: [AssetModel.PriceId: PriceData]
    ) -> Decimal {
        chainModel.assets.compactMap { asset in
            let chainAsset = ChainAsset(chain: chainModel, asset: asset.asset)

            let balanceDecimal = getBalance(
                for: chainAsset,
                accountInfo: accountInfo
            )

            guard let priceId = asset.asset.priceId,
                  let priceData = prices[priceId],
                  let priceDecimal = Decimal(string: priceData.price)
            else {
                return nil
            }

            return priceDecimal * balanceDecimal
        }.reduce(0, +)
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
