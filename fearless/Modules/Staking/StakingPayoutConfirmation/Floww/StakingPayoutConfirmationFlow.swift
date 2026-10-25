import UIKit
import SoraFoundation
import SSFModels

typealias Batch = [PayoutInfo]

enum StakingPayoutConfirmationFlow {
    case relaychain(payouts: [PayoutInfo])
    case pool(rewardAmount: Decimal)
}

protocol StakingPayoutConfirmationModelStateListener: AnyObject {
    func didReceiveError(error: Error)

    func provideFee()
    func provideViewModel()

    func didStartPayout()
    func didCompletePayout(txHashes: [String])
    func didCompletePayout(result: SubmitExtrinsicResult)
    func didFailPayout(error: Error)
}

protocol StakingPayoutConfirmationViewModelState: StakingPayoutConfirmationUserInputHandler {
    var stateListener: StakingPayoutConfirmationModelStateListener? { get set }
    var fee: Decimal? { get }
    var builderClosure: ExtrinsicBuilderClosure? { get }

    func setStateListener(_ stateListener: StakingPayoutConfirmationModelStateListener?)
    func validators(using locale: Locale) -> [DataValidating]
}

struct StakingPayoutConfirmationDependencyContainer {
    let viewModelState: StakingPayoutConfirmationViewModelState
    let strategy: StakingPayoutConfirmationStrategy
    let viewModelFactory: StakingPayoutConfirmationViewModelFactoryProtocol
}

protocol StakingPayoutConfirmationViewModelFactoryProtocol {
    func createPayoutConfirmViewModel(
        viewModelState: StakingPayoutConfirmationViewModelState,
        priceData: PriceData?
    ) -> [LocalizableResource<PayoutConfirmViewModel>]

    func createSinglePayoutConfirmationViewModel(
        viewModelState: StakingPayoutConfirmationViewModelState,
        priceData: PriceData?
    ) -> StakingPayoutConfirmationViewModel?
}

protocol StakingPayoutConfirmationStrategy {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?)
    func submitPayout(builderClosure: ExtrinsicBuilderClosure?)
}

protocol StakingPayoutConfirmationUserInputHandler {}
