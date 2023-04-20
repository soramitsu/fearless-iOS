import Foundation

typealias SwapTransactionDetailModuleCreationResult = (view: SwapTransactionDetailViewInput, input: SwapTransactionDetailModuleInput)

protocol SwapTransactionDetailViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: SwapTransactionViewModel)
    func didReceive(explorer: ChainModel.ExternalApiExplorer?)
}

protocol SwapTransactionDetailViewOutput: AnyObject {
    func didLoad(view: SwapTransactionDetailViewInput)
    func didTapDismiss()
    func didTapCopyTxHash()
    func didTapSubscan()
    func didTapShare()
}

protocol SwapTransactionDetailInteractorInput: AnyObject {
    func setup(with output: SwapTransactionDetailInteractorOutput)
}

protocol SwapTransactionDetailInteractorOutput: AnyObject {
    func didReceive(priceData: PriceData?)
}

protocol SwapTransactionDetailRouterInput: PresentDismissable, SharingPresentable, ApplicationStatusPresentable {
    func presentSubscan(from view: ControllerBackedProtocol?, url: URL)
}

protocol SwapTransactionDetailModuleInput: AnyObject {}

protocol SwapTransactionDetailModuleOutput: AnyObject {}
