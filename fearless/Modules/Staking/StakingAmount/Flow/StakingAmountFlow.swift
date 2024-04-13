
import Foundation
import RobinHood
import SoraFoundation
import SSFModels

enum StakingAmountFlow {
    case relaychain
    case parachain
}

protocol StakingAmountModelStateListener: AnyObject {
    func modelStateDidChanged(viewModelState: StakingAmountViewModelState)
    func provideYourRewardDestinationViewModel(viewModelState: StakingAmountViewModelState)
}

protocol StakingAmountViewModelState: StakingAmountUserInputHandler {
    var stateListener: StakingAmountModelStateListener? { get set }
    var feeExtrinsicBuilderClosure: ExtrinsicBuilderClosure { get }
    var amount: Decimal? { get }
    var fee: Decimal? { get set }
    var bonding: InitiatedBonding? { get }
    var payoutAccount: ChainAccountResponse? { get }
    var learnMoreUrl: URL? { get }
    var continueAvailable: Bool { get }

    func setStateListener(_ stateListener: StakingAmountModelStateListener?)
    func validators(using locale: Locale) -> [DataValidating]
    func updateBalance(_ balance: Decimal?)
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

    func buildYourRewardDestinationViewModel(
        viewModelState: StakingAmountViewModelState,
        priceData: PriceData?,
        calculator: RewardCalculatorEngineProtocol?
    ) -> LocalizableResource<YourRewardDestinationViewModel>?

    func buildSelectRewardDestinationViewModel(
        viewModelState: StakingAmountViewModelState,
        priceData: PriceData?,
        calculator: RewardCalculatorEngineProtocol?
    ) throws -> LocalizableResource<RewardDestinationViewModelProtocol>?
}

extension StakingAmountViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState _: StakingAmountViewModelState,
        priceData _: PriceData?,
        calculator _: RewardCalculatorEngineProtocol?
    ) -> StakingAmountMainViewModel? { nil }

    func buildYourRewardDestinationViewModel(
        viewModelState _: StakingAmountViewModelState,
        priceData _: PriceData?,
        calculator _: RewardCalculatorEngineProtocol?
    ) -> LocalizableResource<YourRewardDestinationViewModel>? { nil }

    func buildSelectRewardDestinationViewModel(
        viewModelState _: StakingAmountViewModelState,
        priceData _: PriceData?,
        calculator _: RewardCalculatorEngineProtocol?
    ) throws -> LocalizableResource<RewardDestinationViewModelProtocol>? { nil }
}

protocol StakingAmountStrategy {
    func setup()
    func estimateFee(extrinsicBuilderClosure: @escaping ExtrinsicBuilderClosure)
}

protocol StakingAmountUserInputHandler {
    func selectRestakeDestination()
    func selectPayoutDestination()
    func selectAmountPercentage(_ percentage: Float)
    func selectPayoutAccount(payoutAccount: ChainAccountResponse?)
    func updateAmount(_ newValue: Decimal)
}

extension StakingAmountUserInputHandler {
    func selectRestakeDestination() {}
    func selectPayoutDestination() {}
    func selectAmountPercentage(_: Float) {}
    func selectPayoutAccount(payoutAccount _: ChainAccountResponse?) {}
    func updateAmount(_: Decimal) {}
}
