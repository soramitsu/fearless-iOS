import Foundation
import CommonWallet
import SoraUI
import SoraFoundation

final class WalletInputAmountView: WalletBaseAmountView {
    var contentInsets = UIEdgeInsets(top: 4.0, left: 0.0, bottom: 14.0, right: 0.0) {
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
            height: 72.0 + contentInsets.top + contentInsets.bottom
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

        amountInputView.textField.placeholder = "0"
        amountInputView.textField.text = nil

        applyLocalization()
    }
}

extension WalletInputAmountView: AmountInputViewProtocol {
    func bind(inputViewModel: AmountInputViewModelProtocol) {
        self.inputViewModel?.observable.remove(observer: self)

        self.inputViewModel = inputViewModel

        self.inputViewModel?.observable.add(observer: self)

        amountInputView.textField.text = inputViewModel.displayAmount == "0" ?
            nil :
            inputViewModel.displayAmount

        fieldBackgroundView.applyEnabledStyle()

        if let viewModel = inputViewModel as? RichAmountInputViewModelProtocol {
            amountInputView.assetIcon = viewModel.icon
            amountInputView.symbol = viewModel.symbol
        }

        applyLocalization()
    }
}

extension WalletInputAmountView: AmountInputViewModelObserver {
    func amountInputDidChange() {
        amountInputView.textField.text = inputViewModel?.displayAmount

        guard let model = inputViewModel as? RichAmountInputViewModelProtocol else {
            amountInputView.priceText = nil
            return
        }

        amountInputView.priceText = model.displayPrice.value(for: selectedLocale)
    }
}

extension WalletInputAmountView: UITextFieldDelegate {
    func textField(
        _: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let model = inputViewModel as? RichAmountInputViewModel else {
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
        amountInputView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: selectedLocale.rLanguages)

        let accessoryView = UIFactory().createAmountAccessoryView(
            for: self,
            locale: selectedLocale
        )

        amountInputView.textField.inputAccessoryView = accessoryView

        guard let viewModel = inputViewModel as? RichAmountInputViewModelProtocol else { return }

        amountInputView.balanceText = viewModel.displayBalance.value(for: selectedLocale)
        amountInputView.priceText = viewModel.displayPrice.value(for: selectedLocale)
    }
}

extension WalletInputAmountView: AmountInputAccessoryViewDelegate {
    func didSelect(on _: AmountInputAccessoryView, percentage: Float) {
        amountInputView.textField.resignFirstResponder()

        guard let model = inputViewModel as? RichAmountInputViewModelProtocol else { return }
        model.didSelectPercentage(percentage)
    }

    func didSelectDone(on _: AmountInputAccessoryView) {
        amountInputView.textField.resignFirstResponder()
    }
}
