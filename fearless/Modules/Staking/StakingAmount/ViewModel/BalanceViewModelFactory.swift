import Foundation
import SoraFoundation
import IrohaCrypto
import CommonWallet
import BigInt
import SoraKeystore

protocol BalanceViewModelFactoryProtocol {
    func priceFromAmount(_ amount: Decimal, priceData: PriceData) -> LocalizableResource<String>
    func amountFromValue(_ value: Decimal) -> LocalizableResource<String>
    func balanceFromPrice(_ amount: Decimal, priceData: PriceData?, isApproximately: Bool)
        -> LocalizableResource<BalanceViewModelProtocol>
    func createBalanceInputViewModel(_ amount: Decimal?) -> LocalizableResource<AmountInputViewModelProtocol>
    func createAssetBalanceViewModel(_ amount: Decimal, balance: Decimal?, priceData: PriceData?)
        -> LocalizableResource<AssetBalanceViewModelProtocol>
}

extension BalanceViewModelFactoryProtocol {
    func balanceFromPrice(
        _ amount: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        balanceFromPrice(amount, priceData: priceData, isApproximately: false)
    }
}

final class BalanceViewModelFactory: BalanceViewModelFactoryProtocol {
    private let targetAssetInfo: AssetBalanceDisplayInfo
    private let limit: Decimal
    private let formatterFactory: AssetBalanceFormatterFactoryProtocol
    private var selectedMetaAccount: MetaAccountModel

    private let eventCenter = EventCenter.shared

    init(
        targetAssetInfo: AssetBalanceDisplayInfo,
        formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory(),
        limit: Decimal = StakingConstants.maxAmount,
        selectedMetaAccount: MetaAccountModel
    ) {
        self.targetAssetInfo = targetAssetInfo
        self.formatterFactory = formatterFactory
        self.limit = limit
        self.selectedMetaAccount = selectedMetaAccount

        eventCenter.add(observer: self, dispatchIn: .main)
    }

    func priceFromAmount(_ amount: Decimal, priceData: PriceData) -> LocalizableResource<String> {
        guard let rate = Decimal(string: priceData.price) else {
            return LocalizableResource { _ in "" }
        }

        let targetAmount = rate * amount
        let priceAssetInfo = AssetBalanceDisplayInfo.forCurrency(selectedMetaAccount.selectedCurrency)
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
        priceData: PriceData?,
        isApproximately: Bool
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        let localizableAmountFormatter = formatterFactory.createTokenFormatter(for: targetAssetInfo)
        let priceAssetInfo = AssetBalanceDisplayInfo.forCurrency(selectedMetaAccount.selectedCurrency)
        let localizablePriceFormatter = formatterFactory.createTokenFormatter(for: priceAssetInfo)

        return LocalizableResource { locale in
            let amountFormatter = localizableAmountFormatter.value(for: locale)

            let amountString = amountFormatter.stringFromDecimal(amount) ?? ""

            guard let priceData = priceData, let rate = Decimal(string: priceData.price) else {
                return BalanceViewModel(amount: amountString, price: nil)
            }

            let targetAmount = rate * amount

            let priceFormatter = localizablePriceFormatter.value(for: locale)
            var priceString = priceFormatter.stringFromDecimal(targetAmount) ?? ""
            if isApproximately {
                priceString.insert("~", at: priceString.startIndex)
            }

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
        let priceAssetInfo = AssetBalanceDisplayInfo.forCurrency(selectedMetaAccount.selectedCurrency)
        let localizablePriceFormatter = formatterFactory.createTokenFormatter(for: priceAssetInfo)

        let symbol = targetAssetInfo.symbol

        let iconViewModel = targetAssetInfo.icon.map { RemoteImageViewModel(url: $0) }

        return LocalizableResource { locale in
            let priceFormatter = localizablePriceFormatter.value(for: locale)
            let priceString: String?

            if let priceData = priceData, let rate = Decimal(string: priceData.price) {
                let targetAmount = rate * amount

                priceString = priceFormatter.stringFromDecimal(targetAmount)
            } else {
                priceString = nil
            }

            let balanceFormatter = localizableBalanceFormatter.value(for: locale)

            var balanceString: String?
            var fiatBalance: String?
            if let balance = balance {
                balanceString = balanceFormatter.stringFromDecimal(balance)

                if let priceData = priceData, let rate = Decimal(string: priceData.price) {
                    fiatBalance = priceFormatter.stringFromDecimal(balance * rate)
                }
            }

            return AssetBalanceViewModel(
                symbol: symbol,
                balance: balanceString,
                fiatBalance: fiatBalance,
                price: priceString,
                iconViewModel: iconViewModel
            )
        }
    }
}

extension BalanceViewModelFactory: EventVisitorProtocol {
    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        selectedMetaAccount = event.account
    }
}
