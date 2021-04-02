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
            height: 52.0 + contentInsets.top + contentInsets.bottom
        )
    }

    var inputViewModel: AmountInputViewModelProtocol?

    override var isFirstResponder: Bool {
        animatedTextField.isFirstResponder
    }

    override func resignFirstResponder() -> Bool {
        animatedTextField.resignFirstResponder()
    }

    override func setupSubviews() {
        super.setupSubviews()

        animatedTextField.delegate = self
        animatedTextField.textField.keyboardType = .decimalPad
    }
}

extension WalletInputAmountView: AmountInputViewProtocol {
    func bind(inputViewModel: AmountInputViewModelProtocol) {
        self.inputViewModel?.observable.remove(observer: self)

        self.inputViewModel = inputViewModel

        self.inputViewModel?.observable.add(observer: self)

        animatedTextField.text = inputViewModel.displayAmount

        fieldBackgroundView.applyEnabledStyle()
    }
}

extension WalletInputAmountView: AmountInputViewModelObserver {
    func amountInputDidChange() {
        animatedTextField.text = inputViewModel?.displayAmount
    }
}

extension WalletInputAmountView: AnimatedTextFieldDelegate {
    func animatedTextField(
        _: AnimatedTextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let model = inputViewModel else {
            return false
        }

        return model.didReceiveReplacement(string, for: range)
    }

    func animatedTextFieldShouldReturn(_: AnimatedTextField) -> Bool {
        true
    }
}

extension WalletInputAmountView: Localizable {
    func applyLocalization() {
        let locale = localizationManager?.selectedLocale
        animatedTextField.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: locale?.rLanguages)
    }
}
