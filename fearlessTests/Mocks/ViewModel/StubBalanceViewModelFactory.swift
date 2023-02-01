import Foundation
import SoraFoundation
import CommonWallet
@testable import fearless

struct StubBalanceViewModelFactory: BalanceViewModelFactoryProtocol {
    func balanceFromPrice(_ amount: Decimal, priceData: fearless.PriceData?, isApproximately: Bool) -> SoraFoundation.LocalizableResource<fearless.BalanceViewModelProtocol> {
        LocalizableResource { _ in
            BalanceViewModel(amount: amount.description, price: priceData?.price.description)
        }
    }
    
    func createAssetBalanceViewModel(_ amount: Decimal?, balance: Decimal?, priceData: fearless.PriceData?) -> SoraFoundation.LocalizableResource<fearless.AssetBalanceViewModelProtocol> {
        LocalizableResource { _ in
            AssetBalanceViewModel(
                symbol: "KSM",
                balance: balance?.description,
                fiatBalance: nil,
                price: priceData?.price.description,
                iconViewModel: nil
            )
        }
    }
    
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

    func createBalanceInputViewModel(_ amount: Decimal?) -> LocalizableResource<fearless.IAmountInputViewModel> {
        LocalizableResource { _ in
            fearless.AmountInputViewModel(symbol: "KSM", amount: amount, formatter: NumberFormatter())
        }
    }
}
