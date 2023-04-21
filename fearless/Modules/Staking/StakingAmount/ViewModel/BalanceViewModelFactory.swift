import Foundation
import SoraFoundation
import IrohaCrypto
import BigInt
import SoraKeystore

protocol BalanceViewModelFactoryProtocol {
    func priceFromAmount(_ amount: Decimal, priceData: PriceData) -> LocalizableResource<String>
    func amountFromValue(_ value: Decimal, usageCase: NumberFormatterUsageCase) -> LocalizableResource<String>
    func balanceFromPrice(_ amount: Decimal, priceData: PriceData?, isApproximately: Bool, usageCase: NumberFormatterUsageCase)
        -> LocalizableResource<BalanceViewModelProtocol>
    func createBalanceInputViewModel(_ amount: Decimal?) -> LocalizableResource<IAmountInputViewModel>
    func createAssetBalanceViewModel(_ amount: Decimal?, balance: Decimal?, priceData: PriceData?)
        -> LocalizableResource<AssetBalanceViewModelProtocol>
}

extension BalanceViewModelFactoryProtocol {
    func balanceFromPrice(
        _ amount: Decimal,
        priceData: PriceData?,
        usageCase: NumberFormatterUsageCase
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        balanceFromPrice(amount, priceData: priceData, isApproximately: false, usageCase: usageCase)
    }
}

final class BalanceViewModelFactory: BalanceViewModelFactoryProtocol {
    private let targetAssetInfo: AssetBalanceDisplayInfo
    private let formatterFactory: AssetBalanceFormatterFactoryProtocol
    private var selectedMetaAccount: MetaAccountModel

    private let eventCenter = EventCenter.shared

    init(
        targetAssetInfo: AssetBalanceDisplayInfo,
        formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory(),
        selectedMetaAccount: MetaAccountModel
    ) {
        self.targetAssetInfo = targetAssetInfo
        self.formatterFactory = formatterFactory
        self.selectedMetaAccount = selectedMetaAccount

        eventCenter.add(observer: self, dispatchIn: .main)
    }

    func priceFromAmount(_ amount: Decimal, priceData: PriceData) -> LocalizableResource<String> {
        guard let rate = Decimal(string: priceData.price) else {
            return LocalizableResource { _ in "" }
        }

        let targetAmount = rate * amount
        let priceAssetInfo = AssetBalanceDisplayInfo.forCurrency(selectedMetaAccount.selectedCurrency)
        let localizableFormatter = formatterFactory.createTokenFormatter(for: priceAssetInfo, usageCase: .fiat)

        return LocalizableResource { locale in
            let formatter = localizableFormatter.value(for: locale)
            return formatter.stringFromDecimal(targetAmount) ?? ""
        }
    }

    func amountFromValue(_ value: Decimal, usageCase: NumberFormatterUsageCase) -> LocalizableResource<String> {
        let localizableFormatter = formatterFactory.createTokenFormatter(for: targetAssetInfo, usageCase: usageCase)

        return LocalizableResource { locale in
            let formatter = localizableFormatter.value(for: locale)
            return formatter.stringFromDecimal(value) ?? ""
        }
    }

    func balanceFromPrice(
        _ amount: Decimal,
        priceData: PriceData?,
        isApproximately: Bool,
        usageCase: NumberFormatterUsageCase
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        let localizableAmountFormatter = formatterFactory.createTokenFormatter(for: targetAssetInfo, usageCase: usageCase)
        let priceAssetInfo = AssetBalanceDisplayInfo.forCurrency(selectedMetaAccount.selectedCurrency)
        let localizablePriceFormatter = formatterFactory.createTokenFormatter(for: priceAssetInfo, usageCase: .fiat)

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
    ) -> LocalizableResource<IAmountInputViewModel> {
        let localizableFormatter = formatterFactory.createInputFormatter(maximumFractionDigits: 6)
        let symbol = targetAssetInfo.symbol

        return LocalizableResource { locale in
            let formatter = localizableFormatter.value(for: locale)
            return AmountInputViewModel(
                symbol: symbol,
                amount: amount,
                formatter: formatter,
                precision: Int16(formatter.maximumFractionDigits)
            )
        }
    }

    func createAssetBalanceViewModel(
        _ amount: Decimal?,
        balance: Decimal?,
        priceData: PriceData?
    ) -> LocalizableResource<AssetBalanceViewModelProtocol> {
        let localizableBalanceFormatter = formatterFactory.createTokenFormatter(for: targetAssetInfo, usageCase: .detailsCrypto)
        let priceAssetInfo = AssetBalanceDisplayInfo.forCurrency(selectedMetaAccount.selectedCurrency)
        let localizablePriceFormatter = formatterFactory.createTokenFormatter(for: priceAssetInfo, usageCase: .fiat)

        let symbol = targetAssetInfo.symbol

        let iconViewModel = targetAssetInfo.icon.map { RemoteImageViewModel(url: $0) }

        return LocalizableResource { locale in
            let priceFormatter = localizablePriceFormatter.value(for: locale)
            let priceString: String?

            if let priceData = priceData, let rate = Decimal(string: priceData.price) {
                let targetAmount = rate * (amount ?? .zero)

                priceString = priceFormatter.stringFromDecimal(targetAmount)
            } else {
                priceString = nil
            }

            let balanceFormatter = localizableBalanceFormatter.value(for: locale)

            var balanceString: String?
            var fiatBalance: String?
            if var balance = balance {
                if balance < 0 {
                    balance = .zero
                }
                balanceString = balanceFormatter.stringFromDecimal(balance)

                if let priceData = priceData, let rate = Decimal(string: priceData.price) {
                    fiatBalance = priceFormatter.stringFromDecimal(balance * rate)
                }

                if let fiatBalance = fiatBalance {
                    balanceString?.append(contentsOf: " (\(fiatBalance))")
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
