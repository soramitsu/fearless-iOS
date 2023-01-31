import Foundation
import BigInt
import SoraFoundation

struct PolkaswapAdjustmentDetailsViewModel {
    let minMaxReceiveVieModel: BalanceViewModelProtocol?
    let minMaxReceiveValue: Decimal
    let route: String
    let fromPerToTitle: String
    let fromPerToValue: String
    let toPerFromTitle: String
    let toPerFromValue: String
    let liqudityProviderFeeVieModel: BalanceViewModelProtocol?
}

protocol PolkaswapAdjustmentViewModelFactoryProtocol {
    func createAmounts(
        xorChainAsset: ChainAsset,
        fromAsset: AssetModel?,
        toAsset: AssetModel?,
        params: PolkaswapQuoteParams,
        quote: [SwapValues]
    ) -> SwapQuoteAmounts?

    func createDetailsViewModel(
        with amounts: SwapQuoteAmounts,
        swapToChainAsset: ChainAsset,
        swapFromChainAsset: ChainAsset,
        swapVariant: SwapVariant,
        availableDexIds: [PolkaswapDex],
        slippadgeTolerance: Float,
        prices: [PriceData]?,
        locale: Locale
    ) -> PolkaswapAdjustmentDetailsViewModel?

    func createBalanceViewModelFactory(
        for chainAsset: ChainAsset
    ) -> BalanceViewModelFactory
}

struct SwapQuoteAmounts {
    static let mockQuoteAmount = SwapQuoteAmounts(
        bestQuote: .mockSwapValues,
        fromAmount: .zero,
        toAmount: .zero,
        lpAmount: .zero
    )

    let bestQuote: SubstrateSwapValues
    let fromAmount: Decimal
    let toAmount: Decimal
    let lpAmount: Decimal
}

final class PolkaswapAdjustmentViewModelFactory: PolkaswapAdjustmentViewModelFactoryProtocol {
    private enum Constants {
        static let imageWidth: CGFloat = 8
        static let imageHeight: CGFloat = 14
        static let imageVerticalPosition: CGFloat = 6
    }

    private let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    private let xorChainAsset: ChainAsset
    private var wallet: MetaAccountModel
    init(
        wallet: MetaAccountModel,
        xorChainAsset: ChainAsset,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    ) {
        self.wallet = wallet
        self.xorChainAsset = xorChainAsset
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }

    func createAmounts(
        xorChainAsset: ChainAsset,
        fromAsset: AssetModel?,
        toAsset: AssetModel?,
        params: PolkaswapQuoteParams,
        quote: [SwapValues]
    ) -> SwapQuoteAmounts? {
        let substrateSwapValues: [SubstrateSwapValues] = quote.compactMap { quote -> SubstrateSwapValues? in
            guard let toAmountBig = BigUInt(quote.amount),
                  let feeBig = BigUInt(quote.fee)
            else {
                return nil
            }
            return SubstrateSwapValues(
                dexId: quote.dexId,
                amount: toAmountBig,
                fee: feeBig,
                rewards: quote.rewards
            )
        }
        guard let bestQuote = substrateSwapValues.sorted(by: {
            $0.amount > $1.amount
        }).first else {
            return nil
        }

        guard
            let fromAmountBig = BigUInt(params.amount),
            let fromAssetPrecision = fromAsset?.precision,
            let toAssetPrecision = toAsset?.precision,
            let fromAmount = Decimal.fromSubstrateAmount(fromAmountBig, precision: Int16(fromAssetPrecision)),
            let toAmount = Decimal.fromSubstrateAmount(bestQuote.amount, precision: Int16(toAssetPrecision)),
            let lpAmount = Decimal.fromSubstrateAmount(bestQuote.fee, precision: Int16(xorChainAsset.asset.precision))
        else {
            return nil
        }

        return SwapQuoteAmounts(
            bestQuote: bestQuote,
            fromAmount: fromAmount,
            toAmount: toAmount,
            lpAmount: lpAmount
        )
    }

    func createDetailsViewModel(
        with amounts: SwapQuoteAmounts,
        swapToChainAsset: ChainAsset,
        swapFromChainAsset: ChainAsset,
        swapVariant: SwapVariant,
        availableDexIds: [PolkaswapDex],
        slippadgeTolerance: Float,
        prices: [PriceData]?,
        locale: Locale
    ) -> PolkaswapAdjustmentDetailsViewModel? {
        guard amounts.toAmount != .zero else {
            return nil
        }
        let minMaxReceiveVieModel = createReceiveOrSoldValue(
            value: amounts.toAmount,
            swapToChainAsset: swapToChainAsset,
            swapFromChainAsset: swapFromChainAsset,
            swapVariant: swapVariant,
            slippadgeTolerance: slippadgeTolerance,
            prices: prices,
            locale: locale
        )
        let route = createSwapRoute(
            dexId: amounts.bestQuote.dexId ?? 0,
            swapToChainAsset: swapToChainAsset,
            swapFromChainAsset: swapFromChainAsset,
            availableDexIds: availableDexIds
        )
        let fromDisplayName = swapFromChainAsset.asset.name
        let toDisplayName = swapToChainAsset.asset.name
        let fromPerToTitle = [fromDisplayName, toDisplayName].joined(separator: " / ")
        let toPerFromTitle = [toDisplayName, fromDisplayName].joined(separator: " / ")

        let fromPerToValue: Decimal
        let toPerFromValue: Decimal
        switch swapVariant {
        case .desiredInput:
            fromPerToValue = amounts.fromAmount / amounts.toAmount
            toPerFromValue = amounts.toAmount / amounts.fromAmount
        case .desiredOutput:
            fromPerToValue = amounts.toAmount / amounts.fromAmount
            toPerFromValue = amounts.fromAmount / amounts.toAmount
        }

        let liqudityProviderFeeVieModel = createLiqitityProviderFeeViewMode(
            lpAmount: amounts.lpAmount,
            prices: prices,
            locale: locale
        )

        let viewModel = PolkaswapAdjustmentDetailsViewModel(
            minMaxReceiveVieModel: minMaxReceiveVieModel.0,
            minMaxReceiveValue: minMaxReceiveVieModel.1,
            route: route,
            fromPerToTitle: fromPerToTitle,
            fromPerToValue: fromPerToValue.toString(locale: locale, digits: .max) ?? "",
            toPerFromTitle: toPerFromTitle,
            toPerFromValue: toPerFromValue.toString(locale: locale, digits: .max) ?? "",
            liqudityProviderFeeVieModel: liqudityProviderFeeVieModel
        )

        return viewModel
    }

    func createBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactory {
        let assetInfo = chainAsset.asset.displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet
        )
        return balanceViewModelFactory
    }

    // MARK: - Private methods

    private func createReceiveOrSoldValue(
        value: Decimal,
        swapToChainAsset: ChainAsset,
        swapFromChainAsset: ChainAsset,
        swapVariant: SwapVariant,
        slippadgeTolerance: Float,
        prices: [PriceData]?,
        locale: Locale
    ) -> (BalanceViewModelProtocol, Decimal) {
        var minMaxValue: Decimal
        var price: PriceData?
        let balanceAsset: ChainAsset
        switch swapVariant {
        case .desiredInput:
            balanceAsset = swapToChainAsset
            minMaxValue = value * Decimal(1 - Double(slippadgeTolerance) / 100.0)
            price = prices?.first(where: { price in
                price.priceId == swapToChainAsset.asset.priceId
            })
        case .desiredOutput:
            balanceAsset = swapFromChainAsset
            minMaxValue = value * Decimal(1 + Double(slippadgeTolerance) / 100.0)
            price = prices?.first(where: { price in
                price.priceId == swapFromChainAsset.asset.priceId
            })
        }

        let balanceViewModelFactory = createBalanceViewModelFactory(for: balanceAsset)
        let receiveValue = balanceViewModelFactory.balanceFromPrice(
            minMaxValue,
            priceData: price,
            isApproximately: true
        ).value(for: locale)

        return (receiveValue, minMaxValue)
    }

    private func createLiqitityProviderFeeViewMode(
        lpAmount: Decimal,
        prices: [PriceData]?,
        locale: Locale
    ) -> BalanceViewModelProtocol {
        let balanceViewModelFactory = createBalanceViewModelFactory(for: xorChainAsset)
        let lpViewModel = balanceViewModelFactory.balanceFromPrice(
            lpAmount,
            priceData: prices?.first(where: { price in
                price.priceId == xorChainAsset.asset.priceId
            }),
            isApproximately: true
        ).value(for: locale)

        return lpViewModel
    }

    private func createSwapRoute(
        dexId: UInt32,
        swapToChainAsset: ChainAsset,
        swapFromChainAsset: ChainAsset,
        availableDexIds: [PolkaswapDex]
    ) -> String {
        let polkaswapDexForRoute = availableDexIds.first { dex in
            dex.code == dexId
        }
        let fromCurrencyId = swapFromChainAsset.asset.currencyId
        let toCurrencyId = swapToChainAsset.asset.currencyId
        let dexCurrencyId = polkaswapDexForRoute?.assetId

        let firstSymbol = swapFromChainAsset.asset.name
        var secondSymbol: String?
        let thirSymbol = swapToChainAsset.asset.name

        if fromCurrencyId != dexCurrencyId, toCurrencyId != dexCurrencyId {
            secondSymbol = polkaswapDexForRoute?.name.uppercased()
        }

        return [firstSymbol, secondSymbol, thirSymbol]
            .compactMap { $0 }
            .joined(separator: "->")
    }

    private func insertArrow(in texts: [String]) -> NSMutableAttributedString {
        let attributedString = NSMutableAttributedString()

        texts.enumerated().forEach { index, text in
            attributedString.append(NSAttributedString(string: text))
            if index % 2 == 0 {
                let imageAttachment = NSTextAttachment()
                imageAttachment.image = R.image.iconSmallArrow()
                imageAttachment.bounds = CGRect(
                    x: 0,
                    y: -Constants.imageVerticalPosition,
                    width: imageAttachment.image?.size.width ?? Constants.imageWidth,
                    height: imageAttachment.image?.size.height ?? Constants.imageHeight
                )

                let imageString = NSAttributedString(attachment: imageAttachment)
                attributedString.append(imageString)
                attributedString.append(NSAttributedString(string: "  "))
            }
        }

        return attributedString
    }
}
