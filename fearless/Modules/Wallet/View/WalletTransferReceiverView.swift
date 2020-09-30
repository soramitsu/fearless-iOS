import Foundation
import CommonWallet

final class WalletTransferReceiverView: WalletBaseReceiverView {}

extension WalletTransferReceiverView: ReceiverViewProtocol {
    func bind(viewModel: MultilineTitleIconViewModelProtocol) {
        self.viewModel = viewModel as? WalletAccountViewModel

        iconView.image = viewModel.icon
        titleLabel.text = viewModel.text
    }
}
