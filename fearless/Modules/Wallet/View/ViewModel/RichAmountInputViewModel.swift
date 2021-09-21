import SoraFoundation
import CommonWallet

protocol RichAmountInputViewModelProtocol: AmountInputViewModelProtocol {
    var balanceViewModelFactory: BalanceViewModelFactoryProtocol { get }
    var priceData: PriceData? { get }
    var displayPrice: LocalizableResource<String> { get }
    var displayBalance: LocalizableResource<String> { get }
    var decimalBalance: Decimal? { get }
    var fee: Decimal? { get }
    var symbol: String { get }
    var icon: UIImage? { get }
    var balance: String? { get }

    func didSelectPercentage(_ percentage: Float)
}

final class RichAmountInputViewModel: RichAmountInputViewModelProtocol {
    let amountInputViewModel: AmountInputViewModelProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let inputFormatter: LocalizableDecimalFormatting

    let symbol: String
    let icon: UIImage?
    let balance: String?
    let priceData: PriceData?
    let decimalBalance: Decimal?
    let fee: Decimal?
    let limit: Decimal

    var displayAmount: String {
        amountInputViewModel.displayAmount
    }

    var decimalAmount: Decimal? {
        amountInputViewModel.decimalAmount
    }

    var isValid: Bool {
        amountInputViewModel.isValid
    }

    var observable: WalletViewModelObserverContainer<AmountInputViewModelObserver> {
        amountInputViewModel.observable
    }

    var displayPrice: LocalizableResource<String> {
        LocalizableResource<String> { [self] locale in
            guard let amount = decimalAmount,
                  let priceData = priceData
            else { return "" }

            return balanceViewModelFactory.balanceFromPrice(
                amount,
                priceData: priceData
            ).value(for: locale).price ?? ""
        }
    }

    var displayBalance: LocalizableResource<String> {
        LocalizableResource<String> { locale in
            R.string.localizable
                .commonAvailableFormat(self.balance ?? "0", preferredLanguages: locale.rLanguages)
        }
    }

    init(
        amountInputViewModel: AmountInputViewModelProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        inputFormatter: LocalizableDecimalFormatting,
        symbol: String,
        icon: UIImage?,
        balance: String?,
        priceData: PriceData?,
        decimalBalance: Decimal?,
        fee: Decimal?,
        limit: Decimal
    ) {
        self.amountInputViewModel = amountInputViewModel
        self.balanceViewModelFactory = balanceViewModelFactory
        self.inputFormatter = inputFormatter
        self.symbol = symbol
        self.icon = icon
        self.balance = balance
        self.priceData = priceData
        self.decimalBalance = decimalBalance
        self.fee = fee
        self.limit = limit
    }

    func didReceiveReplacement(_ string: String, for range: NSRange) -> Bool {
        amountInputViewModel.didReceiveReplacement(string, for: range)
    }

    func didUpdateAmount(to newAmount: String) {
        amountInputViewModel.didUpdateAmount(to: newAmount)
    }

    func didSelectPercentage(_ percentage: Float) {
        if let balance = decimalBalance,
           let fee = fee {
            var newAmount = max(balance - fee, 0.0)
            newAmount = min(newAmount, limit)
            newAmount *= Decimal(Double(percentage))

            let displayAmount = inputFormatter.stringFromDecimal(newAmount) ?? ""

            didUpdateAmount(to: displayAmount)
        }
    }
}
