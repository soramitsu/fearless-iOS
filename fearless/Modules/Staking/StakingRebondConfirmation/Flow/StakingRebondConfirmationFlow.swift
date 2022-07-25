import UIKit
import SoraFoundation

enum StakingRebondConfirmationFlow {
    case relaychain(variant: SelectedRebondVariant)
    case parachain(delegation: ParachainStakingDelegationInfo, request: ParachainStakingScheduledRequest)
}

protocol StakingRebondConfirmationModelStateListener: AnyObject {
    func provideFeeViewModel()
    func provideAssetViewModel()
    func provideConfirmationViewModel()
    func didSubmitRebonding(result: Result<String, Error>)
    func feeParametersDidChanged()
}

protocol StakingRebondConfirmationViewModelState {
    var stateListener: StakingRebondConfirmationModelStateListener? { get set }
    var builderClosure: ExtrinsicBuilderClosure? { get }
    var reuseIdentifier: String? { get }
    var selectableAccountAddress: String? { get }

    func setStateListener(_ stateListener: StakingRebondConfirmationModelStateListener?)
    func dataValidators(locale: Locale) -> [DataValidating]
}

struct StakingRebondConfirmationDependencyContainer {
    let viewModelState: StakingRebondConfirmationViewModelState
    let strategy: StakingRebondConfirmationStrategy
    let viewModelFactory: StakingRebondConfirmationViewModelFactoryProtocol
}

protocol StakingRebondConfirmationViewModelFactoryProtocol {
    func createViewModel(
        viewModelState: StakingRebondConfirmationViewModelState
    ) -> StakingRebondConfirmationViewModel?

    func createFeeViewModel(
        viewModelState: StakingRebondConfirmationViewModelState,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>?

    func createAssetBalanceViewModel(
        viewModelState: StakingRebondConfirmationViewModelState,
        priceData: PriceData?
    )
        -> LocalizableResource<AssetBalanceViewModelProtocol>?
}

protocol StakingRebondConfirmationStrategy {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?)
    func submit(builderClosure: ExtrinsicBuilderClosure?)
}
