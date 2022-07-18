import UIKit

enum StakingBondMoreConfirmationFlowError: Error {}

enum StakingBondMoreConfirmationFlow {
    case relaychain(amount: Decimal)
    case parachain(amount: Decimal, candidate: AccountId)
}

protocol StakingBondMoreConfirmationModelStateListener: AnyObject {
    func provideFeeViewModel()
    func provideAssetViewModel()
    func provideConfirmationViewModel()
    func refreshFeeIfNeeded()

    func didReceiveError(error: Error)

    func didSubmitBonding(result: Result<String, Error>)
}

protocol StakingBondMoreConfirmationViewModelState: StakingBondMoreConfirmationUserInputHandler {
    var stateListener: StakingBondMoreConfirmationModelStateListener? { get set }
    func setStateListener(_ stateListener: StakingBondMoreConfirmationModelStateListener?)

    var amount: Decimal { get }
    var fee: Decimal? { get }
    var balance: Decimal? { get }
    var accountAddress: String? { get }

    var builderClosure: ExtrinsicBuilderClosure? { get }
    var feeReuseIdentifier: String? { get }

    func validators(using locale: Locale) -> [DataValidating]
}

struct StakingBondMoreConfirmationDependencyContainer {
    let viewModelState: StakingBondMoreConfirmationViewModelState
    let strategy: StakingBondMoreConfirmationStrategy
}

protocol StakingBondMoreConfirmationViewModelFactoryProtocol {
//    func buildViewModel(
//        viewModelState: StakingBondMoreConfirmationViewModelState
//    ) -> StakingBondMoreConfirmationViewModel?
}

protocol StakingBondMoreConfirmationStrategy {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?)
    func submit(builderClosure: ExtrinsicBuilderClosure?)
}

protocol StakingBondMoreConfirmationUserInputHandler {}

extension StakingBondMoreConfirmationUserInputHandler {}
