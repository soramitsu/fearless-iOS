typealias SwapTransactionDetailModuleCreationResult = (view: SwapTransactionDetailViewInput, input: SwapTransactionDetailModuleInput)

protocol SwapTransactionDetailViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: SwapTransactionViewModel)
}

protocol SwapTransactionDetailViewOutput: AnyObject {
    func didLoad(view: SwapTransactionDetailViewInput)
    func didTapDismiss()
}

protocol SwapTransactionDetailInteractorInput: AnyObject {
    func setup(with output: SwapTransactionDetailInteractorOutput)
}

protocol SwapTransactionDetailInteractorOutput: AnyObject {
    func didReceive(priceData: PriceData?)
}

protocol SwapTransactionDetailRouterInput: PresentDismissable {}

protocol SwapTransactionDetailModuleInput: AnyObject {}

protocol SwapTransactionDetailModuleOutput: AnyObject {}
