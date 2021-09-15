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
        richTextField.isFirstResponder
    }

    override func resignFirstResponder() -> Bool {
        richTextField.resignFirstResponder()
    }

    override func setupSubviews() {
        super.setupSubviews()

        richTextField.textField.delegate = self
        richTextField.textField.keyboardType = .decimalPad
    }
}

extension WalletInputAmountView: AmountInputViewProtocol {
    func bind(inputViewModel: AmountInputViewModelProtocol) {
        self.inputViewModel?.observable.remove(observer: self)

        self.inputViewModel = inputViewModel

        self.inputViewModel?.observable.add(observer: self)

        richTextField.textField.text = inputViewModel.displayAmount

        fieldBackgroundView.applyEnabledStyle()
    }
}

extension WalletInputAmountView: AmountInputViewModelObserver {
    func amountInputDidChange() {
        richTextField.textField.text = inputViewModel?.displayAmount
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
        richTextField.titleLabel.text = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: locale?.rLanguages)
    }
}
