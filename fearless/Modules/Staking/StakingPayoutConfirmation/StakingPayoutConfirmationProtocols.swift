import SoraFoundation

protocol StakingPayoutConfirmationViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didRecieve(viewModel: [LocalizableResource<RewardConfirmRow>])
    func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol StakingPayoutConfirmationPresenterProtocol: AnyObject {
    func setup()
    func proceed()
    func presentAccountOptions()
}

protocol StakingPayoutConfirmationInteractorInputProtocol: AnyObject {
    func setup()
    func submitPayout()
    func estimateFee()
}

protocol StakingPayoutConfirmationInteractorOutputProtocol: AnyObject {
    func didStartPayout()
    func didCompletePayout(txHash: String)
    func didFailPayout(error: Error)

    func didReceive(paymentInfo: RuntimeDispatchInfo)
    func didReceive(feeError: Error)

    func didReceive(balance: DyAccountData?)
    func didReceive(balanceError: Error)

    func didReceive(price: PriceData?)
    func didReceive(priceError: Error)

    func didRecieve(account: AccountItem, rewardAmount: Decimal)
}

protocol StakingPayoutConfirmationWireframeProtocol: AlertPresentable,
    ErrorPresentable,
    StakingErrorPresentable,
    AddressOptionsPresentable {
    func complete(from view: StakingPayoutConfirmationViewProtocol?)
}

protocol StakingPayoutConfirmationViewFactoryProtocol: AnyObject {
    static func createView(payouts: [PayoutInfo]) -> StakingPayoutConfirmationViewProtocol?
}
