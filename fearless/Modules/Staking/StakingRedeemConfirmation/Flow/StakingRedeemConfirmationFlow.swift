import UIKit
import SoraFoundation
import Web3
import SSFModels

enum StakingRedeemConfirmationFlow {
    case relaychain
    case parachain(
        collator: ParachainStakingCandidateInfo,
        delegation: ParachainStakingDelegation,
        readyForRevoke: BigUInt
    )
    case pool
}

protocol StakingRedeemConfirmationModelStateListener: AnyObject {
    func didReceiveError(error: Error)
    func didSubmitRedeeming(result: Result<String, Error>)
    func provideFeeViewModel()
    func provideAssetViewModel()
    func provideConfirmationViewModel()
    func refreshFeeIfNeeded()
}

protocol StakingRedeemConfirmationViewModelState {
    var stateListener: StakingRedeemConfirmationModelStateListener? { get set }
    var builderClosure: ExtrinsicBuilderClosure? { get }
    var reuseIdentifier: String? { get }
    var fee: Decimal? { get }
    var address: String? { get }

    func setStateListener(_ stateListener: StakingRedeemConfirmationModelStateListener?)
    func validators(using locale: Locale) -> [DataValidating]
}

struct StakingRedeemConfirmationDependencyContainer {
    let viewModelState: StakingRedeemConfirmationViewModelState
    let strategy: StakingRedeemConfirmationStrategy
    let viewModelFactory: StakingRedeemConfirmationViewModelFactoryProtocol
}

protocol StakingRedeemConfirmationViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: StakingRedeemConfirmationViewModelState
    ) -> StakingRedeemConfirmationViewModel?

    func buildAssetViewModel(
        viewModelState: StakingRedeemConfirmationViewModelState,
        priceData: PriceData?
    ) -> LocalizableResource<AssetBalanceViewModelProtocol>?

    func buildHints() -> LocalizableResource<[TitleIconViewModel]>
}

protocol StakingRedeemConfirmationStrategy {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?)
    func submit(builderClosure: ExtrinsicBuilderClosure?)
}
