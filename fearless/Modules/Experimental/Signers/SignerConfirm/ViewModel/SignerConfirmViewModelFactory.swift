import Foundation
import FearlessUtils

protocol SignerConfirmViewModelFactoryProtocol {
    func createCallViewModel(
        from confirmation: SignerConfirmation,
        account: AccountItem,
        priceData: PriceData?,
        locale: Locale
    ) throws -> SignerConfirmCallViewModel

    func createFeeViewModel(
        from confirmation: SignerConfirmation,
        fee: Decimal,
        priceData: PriceData?,
        locale: Locale
    ) -> SignerConfirmFeeViewModel
}

final class SignerConfirmViewModelFactory: SignerConfirmViewModelFactoryProtocol {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let chain: Chain

    lazy var iconGenerator = PolkadotIconGenerator()

    init(balanceViewModelFactory: BalanceViewModelFactoryProtocol, chain: Chain) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chain = chain
    }

    func createCallViewModel(
        from confirmation: SignerConfirmation,
        account: AccountItem,
        priceData: PriceData?,
        locale: Locale
    ) throws -> SignerConfirmCallViewModel {
        let accountIcon = try iconGenerator.generateFromAddress(account.address)

        let amountDecimal = confirmation.amount.map {
            Decimal.fromSubstrateAmount($0, precision: chain.addressType.precision) ?? 0
        }

        let amountViewModel = amountDecimal.map {
            balanceViewModelFactory.balanceFromPrice($0, priceData: priceData).value(for: locale)
        }

        return SignerConfirmCallViewModel(
            accountName: account.username,
            accountIcon: accountIcon,
            moduleName: confirmation.moduleName.displayModule,
            callName: confirmation.callName.displayCall,
            amount: amountViewModel,
            extrinsicString: confirmation.extrinsicString
        )
    }

    func createFeeViewModel(
        from confirmation: SignerConfirmation,
        fee: Decimal,
        priceData: PriceData?,
        locale: Locale
    ) -> SignerConfirmFeeViewModel {
        let amountDecimal = confirmation.amount.map {
            Decimal.fromSubstrateAmount($0, precision: chain.addressType.precision) ?? 0.0
        }

        let totalDecimal = (amountDecimal ?? 0.0) + fee

        return SignerConfirmFeeViewModel(
            fee: balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData).value(for: locale),
            total: balanceViewModelFactory.balanceFromPrice(totalDecimal, priceData: priceData).value(for: locale)
        )
    }
}
