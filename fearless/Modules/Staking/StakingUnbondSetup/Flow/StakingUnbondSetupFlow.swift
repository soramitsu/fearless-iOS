import UIKit
import SoraFoundation

enum StakingUnbondSetupFlowError: Error {}

enum StakingUnbondSetupFlow {
    case relaychain
    case parachain
}

protocol StakingUnbondSetupModelStateListener: AnyObject {
    func didReceiveError(error: Error)

    func provideInputViewModel()
    func provideFeeViewModel()
    func provideAssetViewModel()
    func provideBondingDuration()

    func updateFeeIfNeeded()
}

protocol StakingUnbondSetupViewModelState: StakingUnbondSetupUserInputHandler {
    var stateListener: StakingUnbondSetupModelStateListener? { get set }
    func setStateListener(_ stateListener: StakingUnbondSetupModelStateListener?)

    var inputAmount: Decimal? { get }
    var bonded: Decimal? { get }
    var fee: Decimal? { get }

    func validators(using locale: Locale) -> [DataValidating]

    var builderClosure: ExtrinsicBuilderClosure? { get }
}

struct StakingUnbondSetupDependencyContainer {
    let viewModelState: StakingUnbondSetupViewModelState
    let strategy: StakingUnbondSetupStrategy
    let viewModelFactory: StakingUnbondSetupViewModelFactoryProtocol
}

protocol StakingUnbondSetupViewModelFactoryProtocol {
    func buildBondingDurationViewModel(
        viewModelState: StakingUnbondSetupViewModelState
    ) -> LocalizableResource<String>?
}

protocol StakingUnbondSetupStrategy {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?)
}

protocol StakingUnbondSetupUserInputHandler {
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ amount: Decimal)
}

extension StakingUnbondSetupUserInputHandler {}
