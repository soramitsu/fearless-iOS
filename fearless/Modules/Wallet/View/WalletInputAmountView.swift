import Foundation
import CommonWallet
import SoraUI
import SoraFoundation

final class WalletInputAmountView: WalletBaseAmountView {
    var contentInsets = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16.0, right: 0.0) {
        didSet {
            invalidateIntrinsicContentSize()
        }
    }

    var borderType: BorderType {
        get {
            borderView.borderType
        }

        set {
            borderView.borderType = newValue
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(
            width: UIView.noIntrinsicMetric,
            height: 84.0 + contentInsets.top + contentInsets.bottom
        )
    }

    var inputViewModel: AmountInputViewModelProtocol?

    override var isFirstResponder: Bool {
        amountInputView.isFirstResponder
    }

    override func resignFirstResponder() -> Bool {
        amountInputView.resignFirstResponder()
    }

    override func setupSubviews() {
        super.setupSubviews()

        amountInputView.textField.delegate = self
        amountInputView.textField.keyboardType = .decimalPad

        let accessoryView = UIFactory().createAmountAccessoryView(
            for: self,
            locale: localizationManager?.selectedLocale ?? Locale.current
        )
        amountInputView.textField.inputAccessoryView = accessoryView
    }
}

extension WalletInputAmountView: AmountInputViewProtocol {
    func bind(inputViewModel: AmountInputViewModelProtocol) {
        self.inputViewModel?.observable.remove(observer: self)

        self.inputViewModel = inputViewModel

        self.inputViewModel?.observable.add(observer: self)

        amountInputView.textField.text = inputViewModel.displayAmount

        fieldBackgroundView.applyEnabledStyle()

        if let viewModel = inputViewModel as? AssetBalanceViewModelProtocol {
            amountInputView.assetIcon = viewModel.icon
            amountInputView.balanceText = viewModel.balance
            amountInputView.priceText = viewModel.price
            amountInputView.symbol = viewModel.symbol
        }
    }
}

extension WalletInputAmountView: AmountInputViewModelObserver {
    func amountInputDidChange() {
        amountInputView.textField.text = inputViewModel?.displayAmount
    }
}

extension WalletInputAmountView: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let model = inputViewModel else {
            return false
        }

        return model.didReceiveReplacement(string, for: range)
    }

    func textFieldShouldReturn(_: UITextField) -> Bool {
        true
    }
}

extension WalletInputAmountView: Localizable {
    func applyLocalization() {
        let locale = localizationManager?.selectedLocale
        amountInputView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: locale?.rLanguages)

        // TODO: localize data
    }
}

extension WalletInputAmountView: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage _: Float) {
        amountInputView.textField.resignFirstResponder()

        // TODO: Replace
//        presenter.selectAmountPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        amountInputView.textField.resignFirstResponder()
    }
}

protocol RichAmountInputViewModelProtocol: AmountInputViewModelProtocol & AssetBalanceViewModelProtocol {}

final class RichAmountInputViewModel: RichAmountInputViewModelProtocol {
    let amountInputViewModel: AmountInputViewModelProtocol

    let symbol: String
    let icon: UIImage?
    let balance: String?
    let price: String?

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

    init(
        amountInputViewModel: AmountInputViewModelProtocol,
        symbol: String,
        icon: UIImage?,
        balance: String?,
        price: String?
    ) {
        self.amountInputViewModel = amountInputViewModel
        self.symbol = symbol
        self.icon = icon
        self.balance = balance
        self.price = price
    }

    func didReceiveReplacement(_ string: String, for range: NSRange) -> Bool {
        amountInputViewModel.didReceiveReplacement(string, for: range)
    }
}
