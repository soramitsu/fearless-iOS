import Foundation
import BigInt
import SoraFoundation
import SSFModels

struct PolkaswapAdjustmentDetailsViewModel {
    let minMaxReceiveVieModel: BalanceViewModelProtocol?
    let minMaxReceiveValue: Decimal
    let route: String
    let fromPerToTitle: String
    let fromPerToValue: String
    let toPerFromTitle: String
    let toPerFromValue: String
}

protocol PolkaswapAdjustmentViewModelFactoryProtocol {
    func createAmounts(
        fromAsset: AssetModel?,
        toAsset: AssetModel?,
        params: PolkaswapQuoteParams,
        quote: [SwapValues],
        swapVariant: SwapVariant
    ) -> SwapQuoteAmounts?

    func createDetailsViewModel(
        with amounts: SwapQuoteAmounts,
        swapToChainAsset: ChainAsset,
        swapFromChainAsset: ChainAsset,
        swapVariant: SwapVariant,
        availableDexIds: [PolkaswapDex],
        slippadgeTolerance: Float,
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
        toAmount: .zero
    )

    let bestQuote: SubstrateSwapValues
    let fromAmount: Decimal
    let toAmount: Decimal
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
        fromAsset: AssetModel?,
        toAsset: AssetModel?,
        params: PolkaswapQuoteParams,
        quote: [SwapValues],
        swapVariant: SwapVariant
    ) -> SwapQuoteAmounts? {
        let substrateSwapValues: [SubstrateSwapValues] = quote.compactMap { quote -> SubstrateSwapValues? in
            guard let toAmountBig = BigUInt(quote.amount)
            else {
                return nil
            }
            return SubstrateSwapValues(
                dexId: quote.dexId,
                amount: toAmountBig,
                rewards: quote.rewards
            )
        }

        let bestQuote: SubstrateSwapValues
        switch swapVariant {
        case .desiredInput:
            guard let swapValue = substrateSwapValues.sorted(by: { $0.amount > $1.amount }).first else {
                return nil
            }
            bestQuote = swapValue
        case .desiredOutput:
            guard let swapValue = substrateSwapValues.sorted(by: { $0.amount < $1.amount }).first else {
                return nil
            }
            bestQuote = swapValue
        }

        guard
            let fromAmountBig = BigUInt(params.amount),
            let fromAssetPrecision = fromAsset?.precision,
            let toAssetPrecision = toAsset?.precision,
            let fromAmount = Decimal.fromSubstrateAmount(fromAmountBig, precision: Int16(fromAssetPrecision)),
            let toAmount = Decimal.fromSubstrateAmount(bestQuote.amount, precision: Int16(toAssetPrecision))
        else {
            return nil
        }

        return SwapQuoteAmounts(
            bestQuote: bestQuote,
            fromAmount: fromAmount,
            toAmount: toAmount
        )
    }

    func createDetailsViewModel(
        with amounts: SwapQuoteAmounts,
        swapToChainAsset: ChainAsset,
        swapFromChainAsset: ChainAsset,
        swapVariant: SwapVariant,
        availableDexIds: [PolkaswapDex],
        slippadgeTolerance: Float,
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
            locale: locale
        )
        let route = createSwapRoute(
            dexId: amounts.bestQuote.dexId ?? 0,
            swapToChainAsset: swapToChainAsset,
            swapFromChainAsset: swapFromChainAsset,
            availableDexIds: availableDexIds
        )
        let fromDisplayName = swapFromChainAsset.asset.symbolUppercased
        let toDisplayName = swapToChainAsset.asset.symbolUppercased
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

        let viewModel = PolkaswapAdjustmentDetailsViewModel(
            minMaxReceiveVieModel: minMaxReceiveVieModel.0,
            minMaxReceiveValue: minMaxReceiveVieModel.1,
            route: route,
            fromPerToTitle: fromPerToTitle,
            fromPerToValue: fromPerToValue.toString(locale: locale, maximumDigits: 16) ?? "",
            toPerFromTitle: toPerFromTitle,
            toPerFromValue: toPerFromValue.toString(locale: locale, maximumDigits: 16) ?? ""
        )

        return viewModel
    }

    func createBalanceViewModelFactory(for chainAsset: ChainAsset) -> BalanceViewModelFactory {
        let assetInfo = chainAsset.asset.displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet,
            chainAsset: chainAsset
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
        locale: Locale
    ) -> (BalanceViewModelProtocol, Decimal) {
        var minMaxValue: Decimal
        var price: PriceData?
        let chainAsset: ChainAsset

        switch swapVariant {
        case .desiredInput:
            minMaxValue = value * Decimal(1 - Double(slippadgeTolerance) / 100.0)
            price = swapToChainAsset.asset.getPrice(for: wallet.selectedCurrency)
            chainAsset = swapToChainAsset
        case .desiredOutput:
            minMaxValue = value * Decimal(1 + Double(slippadgeTolerance) / 100.0)
            price = swapFromChainAsset.asset.getPrice(for: wallet.selectedCurrency)
            chainAsset = swapFromChainAsset
        }

        let balanceViewModelFactory = createBalanceViewModelFactory(for: chainAsset)
        let receiveValue = balanceViewModelFactory.balanceFromPrice(
            minMaxValue,
            priceData: price,
            isApproximately: true,
            usageCase: .detailsCrypto
        ).value(for: locale)

        return (receiveValue, minMaxValue)
    }

    private func createLiqitityProviderFeeViewMode(
        lpAmount: Decimal,
        locale: Locale
    ) -> BalanceViewModelProtocol {
        let balanceViewModelFactory = createBalanceViewModelFactory(for: xorChainAsset)
        let lpViewModel = balanceViewModelFactory.balanceFromPrice(
            lpAmount,
            priceData: xorChainAsset.asset.getPrice(for: wallet.selectedCurrency),
            isApproximately: true,
            usageCase: .detailsCrypto
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

        let firstSymbol = swapFromChainAsset.asset.symbolUppercased
        var secondSymbol: String?
        let thirSymbol = swapToChainAsset.asset.symbolUppercased

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
