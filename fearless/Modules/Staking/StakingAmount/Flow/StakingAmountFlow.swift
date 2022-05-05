import CommonWallet
import Foundation
import RobinHood
import SoraFoundation

enum StakingAmountFlow {
    case relaychain
    case parachain
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
