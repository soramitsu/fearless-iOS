import Foundation
import SoraFoundation
import SSFModels

enum ValidatorInfoFlow {
    case relaychain(validatorInfo: ValidatorInfoProtocol?, address: AccountAddress?)
    case parachain(candidate: ParachainStakingCandidateInfo)
    case pool(validatorInfo: ValidatorInfoProtocol?, address: AccountAddress?)
}

protocol ValidatorInfoModelStateListener: AnyObject {
    func modelStateDidChanged(viewModelState: ValidatorInfoViewModelState)
    func didStartLoading()
    func didReceiveError(error: Error)
}

protocol ValidatorInfoViewModelState {
    var stateListener: ValidatorInfoModelStateListener? { get set }
    var validatorAddress: String? { get }

    func setStateListener(_ stateListener: ValidatorInfoModelStateListener?)
}

struct ValidatorInfoDependencyContainer {
    let viewModelState: ValidatorInfoViewModelState
    let strategy: ValidatorInfoStrategy
    let viewModelFactory: ValidatorInfoViewModelFactoryProtocol
}

protocol ValidatorInfoViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: ValidatorInfoViewModelState,
        priceData: PriceData?,
        locale: Locale
    ) -> ValidatorInfoViewModel?

    func buildStakingAmountViewModels(
        viewModelState: ValidatorInfoViewModelState,
        priceData: PriceData?
    ) -> [LocalizableResource<StakingAmountViewModel>]?
}

protocol ValidatorInfoStrategy {
    func setup()
    func reload()
}
