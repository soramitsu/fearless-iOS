import UIKit
import SoraFoundation

enum StakingRedeemFlowError: Error {}

enum StakingRedeemFlow {
    case relaychain
    case parachain
}

protocol StakingRedeemModelStateListener: AnyObject {
    func didReceiveError(error: Error)
    func didSubmitRedeeming(result: Result<String, Error>)
    func provideFeeViewModel()
    func provideAssetViewModel()
    func provideConfirmationViewModel()
    func refreshFeeIfNeeded()
}

protocol StakingRedeemViewModelState: StakingRedeemUserInputHandler {
    var stateListener: StakingRedeemModelStateListener? { get set }
    func setStateListener(_ stateListener: StakingRedeemModelStateListener?)

    func validators(using locale: Locale) -> [DataValidating]

    var builderClosure: ExtrinsicBuilderClosure? { get }
    var reuseIdentifier: String? { get }
    var fee: Decimal? { get }
    var address: String? { get }
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
}

protocol StakingRedeemStrategy {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?)
    func submit(builderClosure: ExtrinsicBuilderClosure?)
}

protocol StakingRedeemUserInputHandler {}

extension StakingRedeemUserInputHandler {}
