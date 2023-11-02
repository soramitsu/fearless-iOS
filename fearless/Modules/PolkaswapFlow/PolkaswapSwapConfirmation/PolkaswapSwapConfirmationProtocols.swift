
import SSFModels

typealias PolkaswapSwapConfirmationModuleCreationResult = (
    view: PolkaswapSwapConfirmationViewInput,
    input: PolkaswapSwapConfirmationModuleInput
)

protocol PolkaswapSwapConfirmationViewInput: ControllerBackedProtocol, LoadableViewProtocol, HiddableBarWhenPushed {
    func didReceive(viewModel: PolkaswapSwapConfirmationViewModel)
}

protocol PolkaswapSwapConfirmationViewOutput: AnyObject {
    func didLoad(view: PolkaswapSwapConfirmationViewInput)
    func didTapBackButton()
    func didTapConfirmButton()
}

protocol PolkaswapSwapConfirmationInteractorInput: AnyObject {
    func setup(with output: PolkaswapSwapConfirmationInteractorOutput)
    func update(params: PolkaswapPreviewParams)
    func submit()
}

protocol PolkaswapSwapConfirmationInteractorOutput: AnyObject {
    func didReceive(extrinsicResult: SubmitExtrinsicResult)
}

protocol PolkaswapSwapConfirmationRouterInput: PushDismissable, SheetAlertPresentable {
    func complete(
        on view: ControllerBackedProtocol?,
        hashString: String,
        chainAsset: ChainAsset,
        completeClosure: (() -> Void)?
    )
}

protocol PolkaswapSwapConfirmationModuleInput: AnyObject {
    func updateModule(with params: PolkaswapPreviewParams)
}

protocol PolkaswapSwapConfirmationModuleOutput: AnyObject {}
