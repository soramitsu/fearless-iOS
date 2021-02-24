import Foundation
import SoraFoundation
import IrohaCrypto
import CommonWallet

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
    let walletPrimitiveFactory: WalletPrimitiveFactoryProtocol
    let selectedAddressType: SNAddressType

    private lazy var formatterFactory = AmountFormatterFactory()
    private lazy var priceAsset = {
        walletPrimitiveFactory.createPriceAsset()
    }()

    private lazy var targetAsset = {
        walletPrimitiveFactory.createAssetForAddressType(selectedAddressType)
    }()

    init(walletPrimitiveFactory: WalletPrimitiveFactoryProtocol, selectedAddressType: SNAddressType) {
        self.walletPrimitiveFactory = walletPrimitiveFactory
        self.selectedAddressType = selectedAddressType
    }

    func priceFromAmount(_ amount: Decimal, priceData: PriceData) -> LocalizableResource<String> {
        guard let rate = Decimal(string: priceData.price) else {
            return LocalizableResource { _ in "" }
        }

        let targetAmount = rate * amount

        let priceAsset = walletPrimitiveFactory.createPriceAsset()
        let localizableFormatter = formatterFactory.createTokenFormatter(for: priceAsset)

        return LocalizableResource { locale in
            let formatter = localizableFormatter.value(for: locale)
            return formatter.string(from: targetAmount) ?? ""
        }
    }

    func amountFromValue(_ value: Decimal) -> LocalizableResource<String> {
        let localizableFormatter = formatterFactory.createTokenFormatter(for: targetAsset)

        return LocalizableResource { locale in
            let formatter = localizableFormatter.value(for: locale)
            return formatter.string(from: value) ?? ""
        }
    }

    func balanceFromPrice(_ amount: Decimal, priceData: PriceData?)
    -> LocalizableResource<BalanceViewModelProtocol> {
        let localizableAmountFormatter = formatterFactory.createTokenFormatter(for: targetAsset)
        let localizablePriceFormatter = formatterFactory.createTokenFormatter(for: priceAsset)

        return LocalizableResource { locale in
            let amountFormatter = localizableAmountFormatter.value(for: locale)

            let amountString = amountFormatter.string(from: amount) ?? ""

            guard let priceData = priceData, let rate = Decimal(string: priceData.price) else {
                return BalanceViewModel(amount: amountString, price: nil)
            }

            let targetAmount = rate * amount

            let priceFormatter = localizablePriceFormatter.value(for: locale)
            let priceString = priceFormatter.string(from: targetAmount) ?? ""

            return BalanceViewModel(amount: amountString, price: priceString)
        }
    }

    func createBalanceInputViewModel(_ amount: Decimal?)
    -> LocalizableResource<AmountInputViewModelProtocol> {
        let localizableFormatter = formatterFactory.createInputFormatter(for: targetAsset)
        let symbol = targetAsset.symbol
        let limit = pow(10, Int(targetAsset.precision))

        return LocalizableResource { locale in
            let formatter = localizableFormatter.value(for: locale)
            return AmountInputViewModel(symbol: symbol,
                                        amount: amount,
                                        limit: limit,
                                        formatter: formatter,
                                        precision: Int16(formatter.maximumFractionDigits))
        }
    }

    func createAssetBalanceViewModel(_ amount: Decimal, balance: Decimal?, priceData: PriceData?)
    -> LocalizableResource<AssetBalanceViewModelProtocol> {

        let localizableBalanceFormatter = formatterFactory.createTokenFormatter(for: targetAsset)
        let localizablePriceFormatter = formatterFactory.createTokenFormatter(for: priceAsset)

        let icon = WalletAssetId(rawValue: targetAsset.identifier)?.icon
        let symbol = targetAsset.symbol

        return LocalizableResource { locale in
            let priceString: String?

            if let priceData = priceData, let rate = Decimal(string: priceData.price) {
                let targetAmount = rate * amount

                let priceFormatter = localizablePriceFormatter.value(for: locale)
                priceString = priceFormatter.string(from: targetAmount)
            } else {
                priceString = nil
            }

            let balanceFormatter = localizableBalanceFormatter.value(for: locale)

            let balanceString: String?

            if let balance = balance {
                balanceString = balanceFormatter.string(from: balance)
            } else {
                balanceString = nil
            }

            return AssetBalanceViewModel(icon: icon,
                                         symbol: symbol,
                                         balance: balanceString,
                                         price: priceString)
        }
    }
}
