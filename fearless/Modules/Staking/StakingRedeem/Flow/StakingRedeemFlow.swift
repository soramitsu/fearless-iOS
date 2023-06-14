import UIKit
import SoraFoundation
import BigInt
import SSFModels

enum StakingRedeemFlow {
    case relaychain
    case parachain(
        collator: ParachainStakingCandidateInfo,
        delegation: ParachainStakingDelegation,
        readyForRevoke: BigUInt
    )
    case pool
}

protocol StakingRedeemModelStateListener: AnyObject {
    func didReceiveError(error: Error)
    func didSubmitRedeeming(result: Result<String, Error>)
    func provideFeeViewModel()
    func provideAssetViewModel()
    func provideConfirmationViewModel()
    func refreshFeeIfNeeded()
}

protocol StakingRedeemViewModelState {
    var stateListener: StakingRedeemModelStateListener? { get set }
    var builderClosure: ExtrinsicBuilderClosure? { get }
    var reuseIdentifier: String? { get }
    var fee: Decimal? { get }
    var address: String? { get }

    func setStateListener(_ stateListener: StakingRedeemModelStateListener?)
    func validators(using locale: Locale) -> [DataValidating]
}

struct StakingRedeemDependencyContainer {
    let viewModelState: StakingRedeemViewModelState
    let strategy: StakingRedeemStrategy
    let viewModelFactory: StakingRedeemViewModelFactoryProtocol
}

protocol StakingRedeemViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: StakingRedeemViewModelState
    ) -> StakingRedeemViewModel?

    func buildAssetViewModel(
        viewModelState: StakingRedeemViewModelState,
        priceData: PriceData?
    ) -> LocalizableResource<AssetBalanceViewModelProtocol>?

    func buildHints() -> LocalizableResource<[TitleIconViewModel]>
}

protocol StakingRedeemStrategy {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?)
    func submit(builderClosure: ExtrinsicBuilderClosure?)
}
