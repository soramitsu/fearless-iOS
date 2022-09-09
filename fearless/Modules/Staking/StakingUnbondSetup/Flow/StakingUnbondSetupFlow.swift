import UIKit
import SoraFoundation

enum StakingUnbondSetupFlow {
    case relaychain
    case parachain(candidate: ParachainStakingCandidateInfo, delegation: ParachainStakingDelegation)
    case pool
}

protocol StakingUnbondSetupModelStateListener: AnyObject {
    func didReceiveError(error: Error)

    func provideInputViewModel()
    func provideFeeViewModel()
    func provideAssetViewModel()
    func provideBondingDuration()

    func provideAccountViewModel()
    func provideCollatorViewModel()

    func updateFeeIfNeeded()
}

protocol StakingUnbondSetupViewModelState: StakingUnbondSetupUserInputHandler {
    var stateListener: StakingUnbondSetupModelStateListener? { get set }
    var inputAmount: Decimal? { get }
    var amount: Decimal? { get }
    var bonded: Decimal? { get }
    var fee: Decimal? { get }
    var builderClosure: ExtrinsicBuilderClosure? { get }
    var confirmationFlow: StakingUnbondConfirmFlow? { get }

    func setStateListener(_ stateListener: StakingUnbondSetupModelStateListener?)
    func validators(using locale: Locale) -> [DataValidating]
}

struct StakingUnbondSetupDependencyContainer {
    let viewModelState: StakingUnbondSetupViewModelState
    let strategy: StakingUnbondSetupStrategy
    let viewModelFactory: StakingUnbondSetupViewModelFactoryProtocol
}

protocol StakingUnbondSetupViewModelFactoryProtocol {
    func buildBondingDurationViewModel(
        viewModelState: StakingUnbondSetupViewModelState
    ) -> LocalizableResource<TitleWithSubtitleViewModel>?

    func buildCollatorViewModel(
        viewModelState: StakingUnbondSetupViewModelState,
        locale: Locale
    ) -> AccountViewModel?

    func buildAccountViewModel(
        viewModelState: StakingUnbondSetupViewModelState,
        locale: Locale
    ) -> AccountViewModel?

    func buildTitleViewModel() -> LocalizableResource<String>

    func buildNetworkFeeViewModel(
        from balanceViewModel: LocalizableResource<BalanceViewModelProtocol>
    ) -> LocalizableResource<NetworkFeeFooterViewModelProtocol>

    func buildHints() -> LocalizableResource<[TitleIconViewModel]>
}

protocol StakingUnbondSetupStrategy {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?)
}

protocol StakingUnbondSetupUserInputHandler {
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ amount: Decimal)
}
