typealias StakingPoolJoinConfirmModuleCreationResult = (view: StakingPoolJoinConfirmViewInput, input: StakingPoolJoinConfirmModuleInput)

protocol StakingPoolJoinConfirmViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(feeViewModel: BalanceViewModelProtocol?)
    func didReceive(confirmViewModel: StakingPoolJoinConfirmViewModel)
}

protocol StakingPoolJoinConfirmViewOutput: AnyObject {
    func didLoad(view: StakingPoolJoinConfirmViewInput)
    func didTapConfirmButton()
    func didTapBackButton()
}

protocol StakingPoolJoinConfirmInteractorInput: AnyObject {
    func setup(with output: StakingPoolJoinConfirmInteractorOutput)
    func estimateFee()
    func submit()
}

protocol StakingPoolJoinConfirmInteractorOutput: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceive(extrinsicResult: SubmitExtrinsicResult)
}

protocol StakingPoolJoinConfirmRouterInput: AnyObject, PushDismissable, AlertPresentable, ErrorPresentable, BaseErrorPresentable, ModalAlertPresenting {
    func finish(view: ControllerBackedProtocol?)
    func complete(
        on view: ControllerBackedProtocol?,
        title: String
    )
}

protocol StakingPoolJoinConfirmModuleInput: AnyObject {}

protocol StakingPoolJoinConfirmModuleOutput: AnyObject {}
