import Foundation
import CommonWallet
import SoraFoundation

final class TransferConfirmAccessoryView: UIView {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var detailsLabel: UILabel!
    @IBOutlet private(set) var actionButton: TriangularedButton!
}

extension TransferConfirmAccessoryView: CommonWallet.AccessoryViewProtocol {
    var contentView: UIView {
        self
    }

    var isActionEnabled: Bool {
        get {
            actionButton.isEnabled
        }
        set(newValue) {
            actionButton.set(enabled: newValue)
        }
    }

    var extendsUnderSafeArea: Bool { true }

    func bind(viewModel: AccessoryViewModelProtocol) {
        actionButton.imageWithTitleView?.title = viewModel.action
        titleLabel.text = viewModel.title
        actionButton.invalidateLayout()

        if let amountViewModel = viewModel as? TransferConfirmAccessoryViewModel {
            detailsLabel.text = amountViewModel.amount
        }

        if let extrinsicViewModel = viewModel as? ExtrinisicConfirmViewModel {
            let amountAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: R.color.colorWhite()!,
                .font: UIFont.p1Paragraph
            ]

            let displayString = NSMutableAttributedString(
                string: extrinsicViewModel.amount,
                attributes: amountAttributes
            )

            if let price = extrinsicViewModel.price {
                let priceAttributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: R.color.colorGray()!,
                    .font: UIFont.p1Paragraph
                ]

                let priceAttributedString = NSMutableAttributedString(
                    string: "  \(price)",
                    attributes: priceAttributes
                )

                displayString.append(priceAttributedString)
            }

            detailsLabel.attributedText = displayString
        }
    }
}
