import UIKit
import SoraFoundation

enum StakingUnbondConfirmFlowError: Error {}

enum StakingUnbondConfirmFlow {
    case relaychain(amount: Decimal)
    case parachain(
        candidate: ParachainStakingCandidateInfo,
        delegation: ParachainStakingDelegation,
        amount: Decimal,
        revoke: Bool,
        bondingDuration: UInt32?
    )
}

protocol StakingUnbondConfirmModelStateListener: AnyObject {
    func didReceiveError(error: Error)

    func didSubmitUnbonding(result: Result<String, Error>)

    func provideFeeViewModel()
    func provideAssetViewModel()
    func provideConfirmationViewModel()
    func refreshFeeIfNeeded()
}

protocol StakingUnbondConfirmViewModelState: StakingUnbondConfirmUserInputHandler {
    var stateListener: StakingUnbondConfirmModelStateListener? { get set }
    func setStateListener(_ stateListener: StakingUnbondConfirmModelStateListener?)

    var inputAmount: Decimal { get }
    var bonded: Decimal? { get }
    var fee: Decimal? { get }
    var accountAddress: AccountAddress? { get }

    func validators(using locale: Locale) -> [DataValidating]

    var builderClosure: ExtrinsicBuilderClosure? { get }
    var reuseIdentifier: String? { get }
}

struct StakingUnbondConfirmDependencyContainer {
    let viewModelState: StakingUnbondConfirmViewModelState
    let strategy: StakingUnbondConfirmStrategy
    let viewModelFactory: StakingUnbondConfirmViewModelFactoryProtocol
}

protocol StakingUnbondConfirmViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: StakingUnbondConfirmViewModelState
    ) -> StakingUnbondConfirmViewModel?

    func buildBondingDurationViewModel(
        viewModelState: StakingUnbondConfirmViewModelState
    ) -> LocalizableResource<TitleWithSubtitleViewModel>?
}

protocol StakingUnbondConfirmStrategy {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?)
    func submit(builderClosure: ExtrinsicBuilderClosure?)
}

protocol StakingUnbondConfirmUserInputHandler {}

extension StakingUnbondConfirmUserInputHandler {}
