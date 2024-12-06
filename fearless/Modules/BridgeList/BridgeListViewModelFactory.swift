import Foundation
import SSFModels
import BigInt

protocol BridgeListViewModelFactory {
    func buildCrossChainViewModel(
        crossChainQuotes: [OKXCrossChainQuote]?,
        locale: Locale,
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        selectedSort: UInt8,
        sourceChainAssets: [ChainAsset]?
    ) -> BridgeListViewModel
}

final class BridgeListViewModelFactoryImpl: BridgeListViewModelFactory {
    private let wallet: MetaAccountModel

    init(wallet: MetaAccountModel) {
        self.wallet = wallet
    }

    func buildCrossChainViewModel(
        crossChainQuotes: [OKXCrossChainQuote]?,
        locale: Locale,
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        selectedSort: UInt8,
        sourceChainAssets: [ChainAsset]?
    ) -> BridgeListViewModel {
        let cellModels = buildViewModels(
            crossChainQuotes: crossChainQuotes,
            sourceChainAsset: sourceChainAsset,
            destinationChainAsset: destinationChainAsset,
            locale: locale,
            selectedSort: selectedSort,
            sourceChainAssets: sourceChainAssets
        )
        return BridgeListViewModel(title: "Trade Routes", cellModels: cellModels)
    }

    private func buildViewModels(
        crossChainQuotes: [OKXCrossChainQuote]?,
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        locale: Locale,
        selectedSort: UInt8,
        sourceChainAssets: [ChainAsset]?
    ) -> [BridgeListTableCellModel]? {
        guard let crossChainQuotes else {
            return nil
        }

        return crossChainQuotes.enumerated().compactMap { index, quote in
            guard
                let amount = quote.routerList.first?.toTokenAmount,
                let amountValue = BigUInt(string: amount),
                let amountDecimal = Decimal.fromSubstrateAmount(amountValue, precision: Int16(destinationChainAsset.asset.precision))
            else {
                return nil
            }
            let balanceViewModelFactory = createBalanceViewModelFactory(for: destinationChainAsset)
            let balanceViewModel = balanceViewModelFactory.balanceFromPrice(amountDecimal, priceData: destinationChainAsset.asset.getPrice(for: wallet.selectedCurrency), usageCase: .detailsCrypto)
            let amountString = String([balanceViewModel.value(for: locale).amount, balanceViewModel.value(for: locale).price].compactMap { $0 }.joined(by: " = "))

            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .abbreviated

            let txTime = (quote.routerList.first?.estimateTime)
                .flatMap { TimeInterval($0) }
                .flatMap { formatter.string(from: TimeInterval($0)) }

            let fee = quote.fee.flatMap { BigUInt(string: $0) }.flatMap { Decimal.fromSubstrateAmount($0, precision: Int16(sourceChainAsset.asset.precision)) }
            let sourceChainFeeNativeToken = sourceChainAsset.chain.chainAssets.first(where: { $0.asset.id == sourceChainAsset.asset.id })

            let sourceChainFiatFee: Decimal? = fee.flatMap { fee in
                guard
                    let sourceChainFeeNativeToken,
                    let price = sourceChainFeeNativeToken.asset.getPrice(for: wallet.selectedCurrency),
                    let priceDecimal = Decimal(string: price.price)
                else {
                    return nil
                }
                return fee * priceDecimal
            }
            let crossChainFeeToken = sourceChainAssets?.first(where: { $0.asset.currencyId == quote.routerList.first?.router.crossChainFeeTokenAddress })
            let crossChainFeeNativeToken = sourceChainAsset.chain.chainAssets.first(where: { $0.asset.id == crossChainFeeToken?.asset.id })
            let crossChainFee: Decimal? = quote.crossChainFee.flatMap { BigUInt(string: $0) }.flatMap {
                guard let crossChainFeeNativeToken else {
                    return nil
                }

                return Decimal.fromSubstrateAmount($0, precision: Int16(crossChainFeeNativeToken.asset.precision))
            }

            let crossChainFiatFee: Decimal? = crossChainFee.flatMap { fee in
                guard let crossChainFeeNativeToken,
                      let price = crossChainFeeNativeToken.asset.getPrice(for: wallet.selectedCurrency),
                      let priceDecimal = Decimal(string: price.price)
                else {
                    return nil
                }

                return fee * priceDecimal
            }

            let totalFiatFee = [crossChainFiatFee, sourceChainFiatFee].compactMap { $0 }.reduce(0, +).string(maximumFractionDigits: 2)

            let txCommission = "\(wallet.selectedCurrency.symbol) \(totalFiatFee)"

            return BridgeListTableCellModel(
                routeTitle: quote.routerList.first?.router.bridgeName.capitalized,
                routeDescription: nil,
                amount: amountString,
                txTime: txTime,
                txCommission: txCommission,
                route: nil,
                isSelected: index == selectedSort,
                sort: UInt8(index)
            )
        }
    }

    private func createBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactoryProtocol {
        BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo, selectedMetaAccount: wallet, chainAsset: chainAsset)
    }
}
