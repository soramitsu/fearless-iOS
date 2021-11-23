import CommonWallet

extension NetworkFeeConfirmView: AccessoryViewProtocol {
    var extendsUnderSafeArea: Bool { true }

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

    func bind(viewModel: AccessoryViewModelProtocol) {
        actionButton.imageWithTitleView?.title = viewModel.action
        networkFeeView.titleLabel.text = viewModel.title
        actionButton.invalidateLayout()

        if let amountViewModel = viewModel as? ExtrinisicConfirmViewModel {
            let feeViewModel = BalanceViewModel(
                amount: amountViewModel.amount,
                price: amountViewModel.price
            )
            networkFeeView.bind(viewModel: feeViewModel)
        }
    }
}
