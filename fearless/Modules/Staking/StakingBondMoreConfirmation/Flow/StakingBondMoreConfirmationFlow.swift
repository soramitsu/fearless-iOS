import UIKit
import SSFModels

enum StakingBondMoreConfirmationFlow {
    case relaychain(amount: Decimal)
    case parachain(amount: Decimal, candidate: ParachainStakingCandidateInfo)
    case pool(amount: Decimal)
}

protocol StakingBondMoreConfirmViewModelFactoryProtocol {
    func createViewModel(
        account: MetaAccountModel,
        amount: Decimal,
        state: StakingBondMoreConfirmationViewModelState,
        locale: Locale,
        priceData: PriceData?
    ) throws -> StakingBondMoreConfirmViewModel?
}

protocol StakingBondMoreConfirmationModelStateListener: AnyObject {
    func provideFeeViewModel()
    func provideAssetViewModel()
    func provideConfirmationViewModel()
    func refreshFeeIfNeeded()

    func didReceiveError(error: Error)

    func didSubmitBonding(result: Result<String, Error>)
}

protocol StakingBondMoreConfirmationViewModelState {
    var stateListener: StakingBondMoreConfirmationModelStateListener? { get set }
    var amount: Decimal { get }
    var fee: Decimal? { get }
    var balance: Decimal? { get }
    var accountAddress: String? { get }
    var builderClosure: ExtrinsicBuilderClosure? { get }
    var feeReuseIdentifier: String? { get }

    func setStateListener(_ stateListener: StakingBondMoreConfirmationModelStateListener?)
    func validators(using locale: Locale) -> [DataValidating]
}

struct StakingBondMoreConfirmationDependencyContainer {
    let viewModelState: StakingBondMoreConfirmationViewModelState
    let strategy: StakingBondMoreConfirmationStrategy
}

protocol StakingBondMoreConfirmationStrategy {
    func setup()
    func estimateFee(builderClosure: ExtrinsicBuilderClosure?, reuseIdentifier: String?)
    func submit(builderClosure: ExtrinsicBuilderClosure?)
}
