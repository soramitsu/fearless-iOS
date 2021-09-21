import UIKit
import SoraUI
import CommonWallet
import SoraFoundation

final class WalletDisplayAmountView: WalletBaseAmountView {
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 116.0)
    }

    var viewModel: RichAmountDisplayViewModelProtocol?
}

extension WalletDisplayAmountView: WalletFormBordering {
    var borderType: BorderType {
        get {
            borderView.borderType
        }
        set(newValue) {
            borderView.borderType = newValue
        }
    }

    func bind(viewModel: RichAmountDisplayViewModel) {
        self.viewModel = viewModel

        amountInputView.titleLabel.text = viewModel.title
        amountInputView.textField.text = viewModel.amount
        amountInputView.isUserInteractionEnabled = false

        fieldBackgroundView.applyDisabledStyle()

        amountInputView.assetIcon = viewModel.icon
        amountInputView.symbol = viewModel.symbol

        applyLocalization()
    }
}

extension WalletDisplayAmountView: Localizable {
    func applyLocalization() {
        amountInputView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: selectedLocale.rLanguages)

        guard let viewModel = viewModel else { return }
        amountInputView.balanceText = viewModel.displayBalance.value(for: selectedLocale)
        amountInputView.priceText = viewModel.displayPrice.value(for: selectedLocale)
    }
}
