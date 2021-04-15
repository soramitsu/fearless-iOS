import SoraFoundation

protocol StakingRewardDetailsViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(with viewModel: StakingRewardDetailsViewModel)
}

protocol StakingRewardDetailsPresenterProtocol: AnyObject {
    func setup()
    func handlePayoutAction()
}

protocol StakingRewardDetailsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol StakingRewardDetailsInteractorOutputProtocol: AnyObject {
    func didRecieve(payoutItem: StakingPayoutItem)
}

protocol StakingRewardDetailsWireframeProtocol: AnyObject {
    func showPayoutConfirmation(from view: ControllerBackedProtocol?)
}

protocol StakingRewardDetailsViewFactoryProtocol: AnyObject {
    static func createView(payoutItem: StakingPayoutItem) -> StakingRewardDetailsViewProtocol?
}
