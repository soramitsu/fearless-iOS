
import SSFModels

typealias PoolRolesConfirmModuleCreationResult = (view: PoolRolesConfirmViewInput, input: PoolRolesConfirmModuleInput)

protocol PoolRolesConfirmViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(feeViewModel: BalanceViewModelProtocol?)
    func didReceive(viewModel: PoolRolesConfirmViewModel)
}

protocol PoolRolesConfirmViewOutput: AnyObject {
    func didLoad(view: PoolRolesConfirmViewInput)
    func didTapConfirmButton()
    func didTapBackButton()
}

protocol PoolRolesConfirmInteractorInput: AnyObject {
    func setup(with output: PoolRolesConfirmInteractorOutput)
    func estimateFee()
    func submit()
}

protocol PoolRolesConfirmInteractorOutput: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceive(extrinsicResult: SubmitExtrinsicResult)
    func didReceive(accounts: [MetaAccountModel])
    func didReceive(error: Error)
}

protocol PoolRolesConfirmRouterInput: PushDismissable,
    SheetAlertPresentable,
    ErrorPresentable,
    BaseErrorPresentable,
    ModalAlertPresenting {
    func finish(view: ControllerBackedProtocol?)
    func complete(
        on view: ControllerBackedProtocol?,
        title: String
    )
}

protocol PoolRolesConfirmModuleInput: AnyObject {}

protocol PoolRolesConfirmModuleOutput: AnyObject {}
