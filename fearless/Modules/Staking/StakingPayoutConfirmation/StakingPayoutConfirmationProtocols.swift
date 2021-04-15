import SoraFoundation

protocol StakingPayoutConfirmationViewProtocol: ControllerBackedProtocol, Localizable {}

protocol StakingPayoutConfirmationPresenterProtocol: AnyObject {
    func setup()
}

protocol StakingPayoutConfirmationInteractorInputProtocol: AnyObject {
    func setup()
    func submitPayout(for lastBalance: Decimal, lastFee: Decimal)
    func estimateFee()
}

protocol StakingPayoutConfirmationInteractorOutputProtocol: AnyObject {
    func didStartPayout()
    func didCompletePayout(txHash: String)
    func didFailPayout(error: Error)

    func didReceive(paymentInfo: RuntimeDispatchInfo)
    func didReceive(feeError: Error)
}

protocol StakingPayoutConfirmationWireframeProtocol: AnyObject {}

protocol StakingPayoutConfirmationViewFactoryProtocol: AnyObject {
    static func createView(payouts: [PayoutInfo]) -> StakingPayoutConfirmationViewProtocol?
}
