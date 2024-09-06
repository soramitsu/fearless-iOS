import Foundation
import SSFModels

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
    func fetchPoolNomination(poolStashAccountId: AccountId)
}

protocol StakingPoolJoinConfirmInteractorOutput: AnyObject {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceive(extrinsicResult: SubmitExtrinsicResult)
    func didReceive(palletIdResult: Result<Data, Error>)
    func didReceive(nomination: Nomination?)
    func didReceive(error: Error)
}

protocol StakingPoolJoinConfirmRouterInput: AnyObject, PushDismissable, SheetAlertPresentable, ErrorPresentable, BaseErrorPresentable, ModalAlertPresenting {
    func finish(view: ControllerBackedProtocol?)
    func complete(
        on view: ControllerBackedProtocol?,
        title: String
    )
}

protocol StakingPoolJoinConfirmModuleInput: AnyObject {}

protocol StakingPoolJoinConfirmModuleOutput: AnyObject {}
