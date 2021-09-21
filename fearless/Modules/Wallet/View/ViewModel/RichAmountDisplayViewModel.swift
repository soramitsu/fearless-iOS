import SoraFoundation
import CommonWallet

protocol RichAmountDisplayViewModelProtocol: WalletFormViewBindingProtocol {
    var displayBalance: LocalizableResource<String> { get }
    var displayPrice: LocalizableResource<String> { get }
    var icon: UIImage? { get }
    var symbol: String { get }
    var balance: String? { get }
}

final class RichAmountDisplayViewModel: RichAmountDisplayViewModelProtocol {
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let displayViewModel: WalletFormSpentAmountModel

    let icon: UIImage?
    let symbol: String
    let balance: String?
    let priceData: PriceData?

    var title: String {
        displayViewModel.title
    }

    var amount: String {
        displayViewModel.amount
    }

    var displayBalance: LocalizableResource<String> {
        LocalizableResource<String> { locale in
            R.string.localizable.commonAvailableFormat(
                self.balance ?? "0",
                preferredLanguages: locale.rLanguages
            )
        }
    }

    var displayPrice: LocalizableResource<String> {
        LocalizableResource<String> { [self] locale in
            guard let amount = Decimal(string: displayViewModel.amount),
                  let priceData = priceData
            else { return "" }

            return balanceViewModelFactory.balanceFromPrice(
                amount,
                priceData: priceData
            ).value(for: locale).price ?? ""
        }
    }

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        displayViewModel: WalletFormSpentAmountModel,
        icon: UIImage?,
        symbol: String,
        balance: String?,
        priceData: PriceData?
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.displayViewModel = displayViewModel
        self.icon = icon
        self.symbol = symbol
        self.balance = balance
        self.priceData = priceData
    }

    func accept(definition: WalletFormDefining) -> WalletFormItemView? {
        if let definition = definition as? WalletFearlessFormDefining {
            return definition.defineViewForAmountDisplay(self)
        } else {
            return nil
        }
    }
}
