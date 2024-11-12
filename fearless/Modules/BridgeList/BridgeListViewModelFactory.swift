import Foundation
import SSFModels
import BigInt

protocol BridgeListViewModelFactory {
    func buildCrossChainViewModel(
        crossChainQuotes: [OKXCrossChainQuote]?,
        locale: Locale,
        destinationChainAsset: ChainAsset,
        selectedSort: UInt8
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
        destinationChainAsset: ChainAsset,
        selectedSort: UInt8
    ) -> BridgeListViewModel {
        let cellModels = buildViewModels(
            crossChainQuotes: crossChainQuotes,
            destinationChainAsset: destinationChainAsset,
            locale: locale,
            selectedSort: selectedSort
        )
        return BridgeListViewModel(title: "Trade Routes", cellModels: cellModels)
    }

    private func buildViewModels(
        crossChainQuotes: [OKXCrossChainQuote]?,
        destinationChainAsset: ChainAsset,
        locale: Locale,
        selectedSort: UInt8
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
            let txCommission = (quote.routerList.first?.router.otherNativeFee).flatMap { "\(wallet.selectedCurrency.symbol) \($0)" }

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
