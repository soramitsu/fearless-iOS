import Foundation
import SSFModels

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

protocol SwapTransactionDetailInteractorOutput: AnyObject {}

protocol SwapTransactionDetailRouterInput: PresentDismissable, SharingPresentable, ApplicationStatusPresentable, WebPresentable {}

protocol SwapTransactionDetailModuleInput: AnyObject {}

protocol SwapTransactionDetailModuleOutput: AnyObject {}
