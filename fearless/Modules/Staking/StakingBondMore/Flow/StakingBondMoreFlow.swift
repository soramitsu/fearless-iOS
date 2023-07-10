import UIKit
import SoraFoundation

enum StakingBondMoreFlow {
    case relaychain
    case parachain(candidate: ParachainStakingCandidateInfo)
    case pool
}

protocol StakingBondMoreModelStateListener: AnyObject {
    func didReceiveError(error: Error)
    func didReceiveInsufficientlyFundsError()
    func feeParametersDidChanged(viewModelState: StakingBondMoreViewModelState)
    func provideAmountInputViewModel()
    func provideFee()
    func provideAsset()
    func provideAccountViewModel()
    func provideCollatorViewModel()
}

protocol StakingBondMoreViewModelState: StakingBondMoreUserInputHandler {
    var amount: Decimal? { get }
    var fee: Decimal? { get }
    var balance: Decimal? { get }
    var stateListener: StakingBondMoreModelStateListener? { get set }
    var builderClosure: ExtrinsicBuilderClosure? { get }
    var feeReuseIdentifier: String? { get }
    var bondMoreConfirmationFlow: StakingBondMoreConfirmationFlow? { get }

    func validators(using locale: Locale) -> [DataValidating]
    func setStateListener(_ stateListener: StakingBondMoreModelStateListener?)
}

protocol StakingBondMoreViewModelFactoryProtocol {
    func buildCollatorViewModel(viewModelState: StakingBondMoreViewModelState, locale: Locale) -> AccountViewModel?
    func buildAccountViewModel(viewModelState: StakingBondMoreViewModelState, locale: Locale) -> AccountViewModel?
    func buildHintViewModel(viewModelState: StakingBondMoreViewModelState, locale: Locale) -> LocalizableResource<String>?
}

struct StakingBondMoreDependencyContainer {
    let viewModelState: StakingBondMoreViewModelState
    let strategy: StakingBondMoreStrategy
    let viewModelFactory: StakingBondMoreViewModelFactoryProtocol?
}

protocol StakingBondMoreStrategy {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?)
}

protocol StakingBondMoreUserInputHandler {
    func updateAmount(_ newValue: Decimal)
    func selectAmountPercentage(_ percentage: Float)
}

extension StakingBondMoreUserInputHandler {}
