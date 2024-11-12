import Foundation
import SSFModels

protocol DexListViewModelFactory {
    func buildSwapViewModel(
        quotes: [OKXDexQuote]?,
        liquiditySources: [OKXLiquiditySource]?,
        locale: Locale,
        chainAsset: ChainAsset,
        selectedDexIds: [String]?
    ) -> DexListViewModel

    func buildCrossChainViewModel(
        crossChainQuotes: [OKXCrossChainQuote]?,
        locale: Locale,
        destinationChainAsset: ChainAsset
    ) -> DexListViewModel
}

final class DexListViewModelFactoryImpl: DexListViewModelFactory {
    private let wallet: MetaAccountModel

    init(wallet: MetaAccountModel) {
        self.wallet = wallet
    }

    func buildSwapViewModel(
        quotes: [OKXDexQuote]?,
        liquiditySources: [OKXLiquiditySource]?,
        locale: Locale,
        chainAsset: ChainAsset,
        selectedDexIds: [String]?
    ) -> DexListViewModel {
        let cellModels = buildViewModels(
            quotes: quotes,
            liquiditySources: liquiditySources,
            chainAsset: chainAsset,
            locale: locale,
            selectedDexIds: selectedDexIds
        )
        return DexListViewModel(title: "Select Liquidity", cellModels: cellModels)
    }

    func buildCrossChainViewModel(crossChainQuotes: [OKXCrossChainQuote]?, locale _: Locale, destinationChainAsset: ChainAsset) -> DexListViewModel {
        let cellModels = buildViewModels(crossChainQuotes: crossChainQuotes, destinationChainAsset: destinationChainAsset)
        return DexListViewModel(title: "Trade Routes", cellModels: cellModels)
    }

    private func buildViewModels(
        quotes: [OKXDexQuote]?,
        liquiditySources: [OKXLiquiditySource]?,
        chainAsset: ChainAsset,
        locale: Locale,
        selectedDexIds: [String]?
    ) -> [DexListTableCellModel]? {
        guard let quotes else {
            return nil
        }

        return quotes.compactMap { quote in
            guard
                let liquiditySource = liquiditySources?.first(where: { $0.name.lowercased() == quote.dexName.lowercased() }),
                let amountDecimal = Decimal(string: quote.amountOut)
            else {
                return nil
            }

            let dexIconViewModel = RemoteImageViewModel(string: quote.dexLogo)
            let balanceViewModelFactory = createBalanceViewModelFactory(for: chainAsset)
            let balanceViewModel = balanceViewModelFactory.balanceFromPrice(amountDecimal, priceData: chainAsset.asset.getPrice(for: wallet.selectedCurrency), usageCase: .detailsCrypto)
            let amountString = String([balanceViewModel.value(for: locale).amount, balanceViewModel.value(for: locale).price].compactMap { $0 }.joined(by: " = "))
            let isSelected = (selectedDexIds?.isEmpty).or(true) || selectedDexIds?.contains(liquiditySource.id) == true

            return DexListTableCellModel(
                dexIcon: dexIconViewModel,
                routeTitle: quote.dexName,
                routeDescription: nil,
                amount: amountString,
                txTime: nil,
                txCommission: "\(wallet.selectedCurrency.symbol) \(quote.tradeFee)",
                route: nil,
                isSelected: isSelected,
                dexId: liquiditySource.id
            )
        }
    }

    private func buildViewModels(crossChainQuotes: [OKXCrossChainQuote]?, destinationChainAsset _: ChainAsset) -> [DexListTableCellModel]? {
        guard let crossChainQuotes else {
            return nil
        }

        return crossChainQuotes.compactMap { quote in
            DexListTableCellModel(
                dexIcon: nil,
                routeTitle: quote.routerList.first?.router.bridgeName,
                routeDescription: nil,
                amount: quote.routerList.first?.toTokenAmount,
                txTime: quote.routerList.first?.estimateTime,
                txCommission: quote.routerList.first?.router.crossChainFee,
                route: nil,
                isSelected: false,
                dexId: ""
            )
        }
    }

    private func createBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactoryProtocol {
        BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo, selectedMetaAccount: wallet, chainAsset: chainAsset)
    }
}
