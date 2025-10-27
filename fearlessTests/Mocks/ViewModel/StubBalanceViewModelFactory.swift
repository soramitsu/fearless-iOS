import Foundation
import SoraFoundation
@testable import fearless
import SSFModels

struct StubBalanceViewModelFactory: BalanceViewModelFactoryProtocol {
    func priceFromAmount(_ amount: Decimal, priceData: PriceData) -> LocalizableResource<String> {
        LocalizableResource { _ in "$\(amount)" }
    }

    func amountFromValue(_ value: Decimal, usageCase: NumberFormatterUsageCase) -> LocalizableResource<String> {
        LocalizableResource { _ in value.description }
    }

    func plainAmountFromValue(_ value: Decimal, usageCase: NumberFormatterUsageCase) -> LocalizableResource<String> {
        LocalizableResource { _ in value.description }
    }

    func balanceFromPrice(
        _ amount: Decimal,
        priceData: PriceData?,
        isApproximately: Bool,
        usageCase: NumberFormatterUsageCase
    ) -> LocalizableResource<BalanceViewModelProtocol> {
        LocalizableResource { _ in
            let price = priceData?.price
            return BalanceViewModel(amount: amount.description, price: price)
        }
    }

    func createBalanceInputViewModel(_ amount: Decimal?) -> LocalizableResource<IAmountInputViewModel> {
        LocalizableResource { _ in
            AmountInputViewModel(symbol: "KSM", amount: amount, formatter: NumberFormatter())
        }
    }

    func createAssetBalanceViewModel(
        _ amount: Decimal?,
        balance: Decimal?,
        priceData: PriceData?,
        selectable: Bool
    ) -> LocalizableResource<AssetBalanceViewModelProtocol> {
        LocalizableResource { _ in
            AssetBalanceViewModel(
                symbol: "KSM",
                balance: balance?.description,
                fiatBalance: nil,
                price: priceData?.price,
                iconViewModel: nil,
                selectable: selectable
            )
        }
    }
}
