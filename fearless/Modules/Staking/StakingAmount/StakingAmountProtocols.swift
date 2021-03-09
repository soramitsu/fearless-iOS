import Foundation
import SoraFoundation
import BigInt
import CommonWallet

protocol StakingAmountViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceiveRewardDestination(viewModel: LocalizableResource<RewardDestinationViewModelProtocol>)
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
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
    func selectLearnMore()
    func proceed()
    func close()
}

protocol StakingAmountInteractorInputProtocol: class {
    func setup()
    func estimateFee(for address: String,
                     amount: BigUInt,
                     rewardDestination: RewardDestination)
    func fetchAccounts()
}

protocol StakingAmountInteractorOutputProtocol: class {
    func didReceive(accounts: [AccountItem])
    func didReceive(price: PriceData?)
    func didReceive(balance: DyAccountData?)
    func didReceive(paymentInfo: RuntimeDispatchInfo,
                    for amount: BigUInt,
                    rewardDestination: RewardDestination)
    func didReceive(error: Error)
    func didReceive(calculator: RewardCalculatorEngineProtocol)
    func didReceive(calculatorError: Error)
    func didReceive(minimalAmount: BigUInt)
}

protocol StakingAmountWireframeProtocol: AlertPresentable, ErrorPresentable,
                                         WebPresentable, StakingErrorPresentable {
    func presentAccountSelection(_ accounts: [AccountItem],
                                 selectedAccountItem: AccountItem,
                                 delegate: ModalPickerViewControllerDelegate,
                                 from view: StakingAmountViewProtocol?,
                                 context: AnyObject?)

    func proceed(from view: StakingAmountViewProtocol?, result: StartStakingResult)

    func close(view: StakingAmountViewProtocol?)
}

protocol StakingAmountViewFactoryProtocol: class {
    static func createView(with amount: Decimal?) -> StakingAmountViewProtocol?
}
