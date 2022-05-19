import CommonWallet
import Foundation
import RobinHood
import SoraFoundation

enum StakingAmountFlow {
    case relaychain
    case parachain
}

protocol StakingAmountModelStateListener: AnyObject {
    func modelStateDidChanged(viewModelState: StakingAmountViewModelState)
}

protocol StakingAmountViewModelState: StakingAmountUserInputHandler {
    var stateListener: StakingAmountModelStateListener? { get set }
    var feeExtrinsicBuilderClosure: ExtrinsicBuilderClosure { get }
    var validators: [DataValidating] { get }

    var amount: Decimal? { get set }
    var fee: Decimal? { get set }

    func setStateListener(_ stateListener: StakingAmountModelStateListener?)
}

struct StakingAmountDependencyContainer {
    let viewModelState: StakingAmountViewModelState
    let strategy: StakingAmountStrategy
    let viewModelFactory: StakingAmountViewModelFactoryProtocol
}

protocol StakingAmountViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: StakingAmountViewModelState,
        priceData: PriceData?,
        calculator: RewardCalculatorEngineProtocol?
    ) -> StakingAmountMainViewModel?
}

protocol StakingAmountStrategy {
    func setup()
    func estimateFee(extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure)
}

protocol StakingAmountUserInputHandler {
    func selectRestakeDestination()
    func selectPayoutDestination()
    func selectAmountPercentage(_ percentage: Float)
    func selectPayoutAccount()
    func updateAmount(_ newValue: Decimal)
}

extension StakingAmountUserInputHandler {
    func selectRestakeDestination() {}
    func selectPayoutDestination() {}
    func selectAmountPercentage(_: Float) {}
    func selectPayoutAccount() {}
    func updateAmount(_: Decimal) {}
}
