import UIKit
import SoraFoundation

typealias Batch = [PayoutInfo]

enum StakingPayoutConfirmationFlow {
    case relaychain
    case pool
}

protocol StakingPayoutConfirmationModelStateListener: AnyObject {
    func didReceiveError(error: Error)

    func provideFee()
    func provideViewModel()

    func didStartPayout()
    func didCompletePayout(txHashes: [String])
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
}

protocol StakingPayoutConfirmationStrategy {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?)
    func submitPayout(builderClosure: ExtrinsicBuilderClosure?)
}

protocol StakingPayoutConfirmationUserInputHandler {}
