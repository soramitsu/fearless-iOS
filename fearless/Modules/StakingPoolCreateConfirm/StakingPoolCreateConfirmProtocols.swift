typealias StakingPoolCreateConfirmModuleCreationResult = (
    view: StakingPoolCreateConfirmViewInput,
    input: StakingPoolCreateConfirmModuleInput
)

protocol StakingPoolCreateConfirmViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(feeViewModel: BalanceViewModelProtocol?)
    func didReceive(confirmViewModel: StakingPoolCreateConfirmViewModel)
}

protocol StakingPoolCreateConfirmViewOutput: AnyObject {
    func didLoad(view: StakingPoolCreateConfirmViewInput)
    func didTapBackButton()
    func didTapConfirmButton()
}

protocol StakingPoolCreateConfirmInteractorInput: AnyObject {
    func setup(with output: StakingPoolCreateConfirmInteractorOutput)
    func estimateFee()
    func submit()
}

protocol StakingPoolCreateConfirmInteractorOutput: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceive(extrinsicResult: SubmitExtrinsicResult)
}

protocol StakingPoolCreateConfirmRouterDeps:
    PushDismissable,
    AlertPresentable,
    ErrorPresentable,
    BaseErrorPresentable,
    ModalAlertPresenting {}

protocol StakingPoolCreateConfirmRouterInput: StakingPoolCreateConfirmRouterDeps {
    func finish(view: ControllerBackedProtocol?)
    func complete(
        on view: ControllerBackedProtocol?,
        title: String
    )
}

protocol StakingPoolCreateConfirmModuleInput: AnyObject {}

protocol StakingPoolCreateConfirmModuleOutput: AnyObject {}
