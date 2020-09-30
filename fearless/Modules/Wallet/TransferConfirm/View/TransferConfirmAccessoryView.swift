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
            actionButton.isEnabled = newValue
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
    }
}
