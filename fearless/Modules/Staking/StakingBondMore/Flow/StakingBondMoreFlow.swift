import UIKit

enum StakingBondMoreFlowError: Error {}

enum StakingBondMoreFlow {
    case relaychain
    case parachain(candidate: ParachainStakingCandidateInfo)
}

protocol StakingBondMoreModelStateListener: AnyObject {
    func didReceiveError(error: Error)
    func didReceiveInsufficientlyFundsError()

    func feeParametersDidChanged(viewModelState: StakingBondMoreViewModelState)

    func provideAmountInputViewModel()
    func provideFee()
    func provideAsset()
}

protocol StakingBondMoreViewModelState: StakingBondMoreUserInputHandler {
    var amount: Decimal { get }
    var fee: Decimal? { get }
    var balance: Decimal? { get }

    func validators(using locale: Locale) -> [DataValidating]

    var stateListener: StakingBondMoreModelStateListener? { get set }
    func setStateListener(_ stateListener: StakingBondMoreModelStateListener?)

    var builderClosure: ExtrinsicBuilderClosure? { get }
    var feeReuseIdentifier: String? { get }

    var bondMoreConfirmationFlow: StakingBondMoreConfirmationFlow? { get }
}

struct StakingBondMoreDependencyContainer {
    let viewModelState: StakingBondMoreViewModelState
    let strategy: StakingBondMoreStrategy
}

protocol StakingBondMoreViewModelFactoryProtocol {}

protocol StakingBondMoreStrategy {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?)
}

protocol StakingBondMoreUserInputHandler {
    func updateAmount(_ newValue: Decimal)
    func selectAmountPercentage(_ percentage: Float)
}

extension StakingBondMoreUserInputHandler {}
