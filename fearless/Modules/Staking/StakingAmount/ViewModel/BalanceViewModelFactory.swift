import Foundation
import SoraFoundation
import IrohaCrypto
import CommonWallet
import BigInt

protocol BalanceViewModelFactoryProtocol {
    func priceFromAmount(_ amount: Decimal, priceData: PriceData) -> LocalizableResource<String>
    func amountFromValue(_ value: Decimal) -> LocalizableResource<String>
    func balanceFromPrice(_ amount: Decimal, priceData: PriceData?)
        -> LocalizableResource<BalanceViewModelProtocol>
    func createBalanceInputViewModel(_ amount: Decimal?) -> LocalizableResource<AmountInputViewModelProtocol>
    func createAssetBalanceViewModel(_ amount: Decimal, balance: Decimal?, priceData: PriceData?)
        -> LocalizableResource<AssetBalanceViewModelProtocol>
}

final class BalanceViewModelFactory: BalanceViewModelFactoryProtocol {
    let targetAssetInfo: AssetBalanceDisplayInfo
    let priceAssetInfo: AssetBalanceDisplayInfo
    let limit: Decimal

    private let formatterFactory: AssetBalanceFormatterFactoryProtocol

    @available(*, deprecated, message: "Use init(targetAssetInfo:priceAssetInfo)")
    init(
        walletPrimitiveFactory _: WalletPrimitiveFactoryProtocol,
        selectedAddressType _: SNAddressType,
        limit: Decimal,
        formatterFactory _: NumberFormatterFactoryProtocol = AmountFormatterFactory()
    ) {
        targetAssetInfo = AssetBalanceDisplayInfo.usd()
        priceAssetInfo = AssetBalanceDisplayInfo.usd()
        self.limit = limit
        formatterFactory = AssetBalanceFormatterFactory()
    }

    init(
        targetAssetInfo: AssetBalanceDisplayInfo,
        priceAssetInfo: AssetBalanceDisplayInfo = AssetBalanceDisplayInfo.usd(),
        formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory(),
        limit: Decimal = StakingConstants.maxAmount
    ) {
        self.targetAssetInfo = targetAssetInfo
        self.priceAssetInfo = priceAssetInfo
        self.formatterFactory = formatterFactory
        self.limit = limit
    }

    func priceFromAmount(_ amount: Decimal, priceData: PriceData) -> LocalizableResource<String> {
        guard let rate = Decimal(string: priceData.price) else {
            return LocalizableResource { _ in "" }
        }

        let targetAmount = rate * amount

        let localizableFormatter = formatterFactory.createTokenFormatter(for: priceAssetInfo)

        return LocalizableResource { locale in
            let formatter = localizableFormatter.value(for: locale)
            return formatter.stringFromDecimal(targetAmount) ?? ""
        }
    }

    func amountFromValue(_ value: Decimal) -> LocalizableResource<String> {
        let localizableFormatter = formatterFactory.createTokenFormatter(for: targetAssetInfo)

        return LocalizableResource { locale in
            let formatter = localizableFormatter.value(for: locale)
            return formatter.stringFromDecimal(value) ?? ""
        }
    }

    func balanceFromPrice(
        _ amount: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        let localizableAmountFormatter = formatterFactory.createTokenFormatter(for: targetAssetInfo)
        let localizablePriceFormatter = formatterFactory.createTokenFormatter(for: priceAssetInfo)

        return LocalizableResource { locale in
            let amountFormatter = localizableAmountFormatter.value(for: locale)

            let amountString = amountFormatter.stringFromDecimal(amount) ?? ""

            guard let priceData = priceData, let rate = Decimal(string: priceData.price) else {
                return BalanceViewModel(amount: amountString, price: nil)
            }

            let targetAmount = rate * amount

            let priceFormatter = localizablePriceFormatter.value(for: locale)
            let priceString = priceFormatter.stringFromDecimal(targetAmount) ?? ""

            return BalanceViewModel(amount: amountString, price: priceString)
        }
    }

    func createBalanceInputViewModel(
        _ amount: Decimal?
    ) -> LocalizableResource<AmountInputViewModelProtocol> {
        let localizableFormatter = formatterFactory.createInputFormatter(for: targetAssetInfo)
        let symbol = targetAssetInfo.symbol

        let currentLimit = limit

        return LocalizableResource { locale in
            let formatter = localizableFormatter.value(for: locale)
            return AmountInputViewModel(
                symbol: symbol,
                amount: amount,
                limit: currentLimit,
                formatter: formatter,
                precision: Int16(formatter.maximumFractionDigits)
            )
        }
    }

    func createAssetBalanceViewModel(
        _ amount: Decimal,
        balance: Decimal?,
        priceData: PriceData?
    ) -> LocalizableResource<AssetBalanceViewModelProtocol> {
        let localizableBalanceFormatter = formatterFactory.createTokenFormatter(for: targetAssetInfo)
        let localizablePriceFormatter = formatterFactory.createTokenFormatter(for: priceAssetInfo)

        let symbol = targetAssetInfo.symbol

        let iconViewModel = targetAssetInfo.icon.map { RemoteImageViewModel(url: $0) }

        return LocalizableResource { locale in
            let priceString: String?

            if let priceData = priceData, let rate = Decimal(string: priceData.price) {
                let targetAmount = rate * amount

                let priceFormatter = localizablePriceFormatter.value(for: locale)
                priceString = priceFormatter.stringFromDecimal(targetAmount)
            } else {
                priceString = nil
            }

            let balanceFormatter = localizableBalanceFormatter.value(for: locale)

            let balanceString: String?

            if let balance = balance {
                balanceString = balanceFormatter.stringFromDecimal(balance)
            } else {
                balanceString = nil
            }

            return AssetBalanceViewModel(
                symbol: symbol,
                balance: balanceString,
                price: priceString,
                iconViewModel: iconViewModel
            )
        }
    }
}
