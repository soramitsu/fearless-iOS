import Foundation

protocol WalletSendConfirmViewModelFactoryProtocol {
    func buildViewModel(
        amount: Decimal,
        senderAccountViewModel: AccountViewModel?,
        receiverAccountViewModel: AccountViewModel?,
        assetBalanceViewModel: AssetBalanceViewModelProtocol?,
        feeViewModel: BalanceViewModelProtocol?,
        locale: Locale
    ) -> WalletSendConfirmViewModel
}

class WalletSendConfirmViewModelFactory: WalletSendConfirmViewModelFactoryProtocol {
    let amountFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let assetInfo: AssetBalanceDisplayInfo

    init(amountFormatterFactory: AssetBalanceFormatterFactoryProtocol, assetInfo: AssetBalanceDisplayInfo) {
        self.amountFormatterFactory = amountFormatterFactory
        self.assetInfo = assetInfo
    }

    func buildViewModel(
        amount: Decimal,
        senderAccountViewModel: AccountViewModel?,
        receiverAccountViewModel: AccountViewModel?,
        assetBalanceViewModel: AssetBalanceViewModelProtocol?,
        feeViewModel: BalanceViewModelProtocol?,
        locale: Locale
    ) -> WalletSendConfirmViewModel {
        let formatter = amountFormatterFactory.createDisplayFormatter(for: assetInfo).value(for: locale)
        let inputAmount = formatter.stringFromDecimal(amount) ?? ""

        return WalletSendConfirmViewModel(
            amountString: inputAmount,
            senderAccountViewModel: senderAccountViewModel,
            receiverAccountViewModel: receiverAccountViewModel,
            assetBalanceViewModel: assetBalanceViewModel,
            feeViewModel: feeViewModel
        )
    }
}
