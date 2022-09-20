import UIKit
import SoraFoundation

enum StakingUnbondConfirmFlow {
    case relaychain(amount: Decimal)
    case parachain(
        candidate: ParachainStakingCandidateInfo,
        delegation: ParachainStakingDelegation,
        amount: Decimal,
        revoke: Bool,
        bondingDuration: UInt32?
    )
    case pool(amount: Decimal)
}

protocol StakingUnbondConfirmModelStateListener: AnyObject {
    func didReceiveError(error: Error)

    func didSubmitUnbonding(result: Result<String, Error>)

    func provideFeeViewModel()
    func provideAssetViewModel()
    func provideConfirmationViewModel()
    func refreshFeeIfNeeded()
}

protocol StakingUnbondConfirmViewModelState {
    var stateListener: StakingUnbondConfirmModelStateListener? { get set }
    var inputAmount: Decimal { get }
    var bonded: Decimal? { get }
    var fee: Decimal? { get }
    var accountAddress: AccountAddress? { get }
    var builderClosure: ExtrinsicBuilderClosure? { get }
    var reuseIdentifier: String? { get }

    func validators(using locale: Locale) -> [DataValidating]
    func setStateListener(_ stateListener: StakingUnbondConfirmModelStateListener?)
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
