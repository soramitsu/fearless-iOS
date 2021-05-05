import Foundation
import SoraFoundation
import CommonWallet
@testable import fearless

struct StubBalanceViewModelFactory: BalanceViewModelFactoryProtocol {
    func priceFromAmount(_ amount: Decimal, priceData: PriceData) -> LocalizableResource<String> {
        LocalizableResource { _ in
            "$100"
        }
    }

    func amountFromValue(_ value: Decimal) -> LocalizableResource<String> {
        LocalizableResource { _ in
            "$100"
        }
    }

    func balanceFromPrice(_ amount: Decimal, priceData: PriceData?) -> LocalizableResource<BalanceViewModelProtocol> {
        LocalizableResource { _ in
            BalanceViewModel(amount: amount.description, price: priceData?.price.description)
        }
    }

    func createBalanceInputViewModel(_ amount: Decimal?) -> LocalizableResource<AmountInputViewModelProtocol> {
        LocalizableResource { _ in
            AmountInputViewModel(symbol: "KSM", amount: amount, limit: 0, formatter: NumberFormatter())
        }
    }

    func createAssetBalanceViewModel(_ amount: Decimal, balance: Decimal?, priceData: PriceData?) -> LocalizableResource<AssetBalanceViewModelProtocol> {
        LocalizableResource { _ in
            AssetBalanceViewModel(icon: nil, symbol: "KSM", balance: balance?.description, price: priceData?.price.description)
        }
    }
}
