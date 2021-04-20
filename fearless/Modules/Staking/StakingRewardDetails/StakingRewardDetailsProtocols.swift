import SoraFoundation

protocol StakingRewardDetailsViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(with viewModel: LocalizableResource<StakingRewardDetailsViewModel>)
}

protocol StakingRewardDetailsPresenterProtocol: AnyObject {
    func setup()
    func handlePayoutAction()
    func handleValidatorAccountAction()
}

protocol StakingRewardDetailsInteractorInputProtocol: AnyObject {}

protocol StakingRewardDetailsInteractorOutputProtocol: AnyObject {}

protocol StakingRewardDetailsWireframeProtocol: AnyObject, AddressOptionsPresentable {
    func showPayoutConfirmation(from view: ControllerBackedProtocol?, payoutInfo: PayoutInfo)
}

protocol StakingRewardDetailsViewFactoryProtocol: AnyObject {
    static func createView(input: StakingRewardDetailsInput) -> StakingRewardDetailsViewProtocol?
}

struct StakingRewardDetailsInput {
    let payoutInfo: PayoutInfo
    let chain: Chain
    let activeEra: EraIndex
    let historyDepth: UInt32
}
