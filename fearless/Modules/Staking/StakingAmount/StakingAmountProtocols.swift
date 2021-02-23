import Foundation
import SoraFoundation
import BigInt
import CommonWallet

protocol StakingAmountViewProtocol: ControllerBackedProtocol {
    func didReceiveRewardDestination(viewModel: LocalizableResource<RewardDestinationViewModelProtocol>)
    func didReceiveAmountPrice(viewModel: LocalizableResource<String>)
    func didReceiveBalance(viewModel: LocalizableResource<String>)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceiveInput(viewModel: LocalizableResource<AmountInputViewModelProtocol>)
}

protocol StakingAmountPresenterProtocol: class {
    func setup()
    func selectRestakeDestination()
    func selectPayoutDestination()
    func selectAmountPercentage(_ percentage: Float)
    func selectPayoutAccount()
    func updateAmount(_ newValue: Decimal)
    func close()
}

protocol StakingAmountInteractorInputProtocol: class {
    func setup()
    func estimateFee(for address: String, amount: BigUInt, rewardDestination: RewardDestination)
    func fetchAccounts()
}

protocol StakingAmountInteractorOutputProtocol: class {
    func didReceive(accounts: [ManagedAccountItem])
    func didReceive(price: PriceData?)
    func didReceive(balance: DyAccountData?)
    func didReceive(paymentInfo: RuntimeDispatchInfo, for amount: BigUInt, rewardDestination: RewardDestination)
    func didReceive(error: Error)
}

protocol StakingAmountWireframeProtocol: class {
    func close(view: StakingAmountViewProtocol?)
}

protocol StakingAmountViewFactoryProtocol: class {
	static func createView() -> StakingAmountViewProtocol?
}
