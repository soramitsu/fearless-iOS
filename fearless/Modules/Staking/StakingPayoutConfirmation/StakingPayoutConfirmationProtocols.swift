import SoraFoundation

protocol StakingPayoutConfirmationViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol StakingPayoutConfirmationPresenterProtocol: AnyObject {
    func setup()
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
}

protocol StakingPayoutConfirmationWireframeProtocol: AlertPresentable, ErrorPresentable, StakingErrorPresentable {
    func complete(from view: StakingPayoutConfirmationViewProtocol?)
}

protocol StakingPayoutConfirmationViewFactoryProtocol: AnyObject {
    static func createView(payouts: [PayoutInfo]) -> StakingPayoutConfirmationViewProtocol?
}
