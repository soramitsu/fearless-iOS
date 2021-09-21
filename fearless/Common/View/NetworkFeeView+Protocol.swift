import Foundation
import CommonWallet
import SoraUI

extension NetworkFeeView: FeeViewProtocol {
    var borderType: BorderType {
        get {
            borderView.borderType
        }

        set(newValue) {
            borderView.borderType = newValue
        }
    }

    func bind(viewModel: FeeViewModelProtocol) {
        if let viewModel = viewModel as? BalanceViewModelProtocol {
            bind(viewModel: viewModel)
        }
    }
}
