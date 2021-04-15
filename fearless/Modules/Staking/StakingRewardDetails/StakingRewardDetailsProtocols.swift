import SoraFoundation

protocol StakingRewardDetailsViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(with viewModel: StakingRewardDetailsViewModel)
}

protocol StakingRewardDetailsPresenterProtocol: AnyObject {
    func setup()
    func handlePayoutAction()
    func handleValidatorAccountAction()
}

protocol StakingRewardDetailsInteractorInputProtocol: AnyObject {}

protocol StakingRewardDetailsInteractorOutputProtocol: AnyObject {}

protocol StakingRewardDetailsWireframeProtocol: AnyObject, AddressOptionsPresentable {
    func showPayoutConfirmation(from view: ControllerBackedProtocol?)
}

protocol StakingRewardDetailsViewFactoryProtocol: AnyObject {
    static func createView(payoutItem: StakingPayoutItem, chain: Chain) -> StakingRewardDetailsViewProtocol?
}
