import SoraFoundation

protocol ReferralCrowdloanViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveState(state: ReferralCrowdloanViewState)
    func didReceiveLearnMore(viewModel: LearnMoreViewModel)
    func didReceiveInput(viewModel: InputViewModelProtocol)
    func didReceiveShouldInputCode()
    func didReceiveShouldAgreeTerms()
}

protocol ReferralCrowdloanPresenterProtocol: AnyObject {
    init(
        wireframe: ReferralCrowdloanWireframeProtocol,
        bonusService: CrowdloanBonusServiceProtocol,
        displayInfo: CrowdloanDisplayInfo,
        inputAmount: Decimal,
        crowdloanDelegate: CustomCrowdloanDelegate,
        crowdloanViewModelFactory: CrowdloanContributionViewModelFactoryProtocol,
        defaultReferralCode: String,
        localizationManager: LocalizationManagerProtocol
    )

    var view: ReferralCrowdloanViewProtocol? { get set }

    func setup()
    func update(referralCode: String)
    func applyDefaultCode()
    func applyInputCode()
    func setTermsAgreed(value: Bool)
    func presentTerms()
    func presentLearnMore()
}

protocol ReferralCrowdloanWireframeProtocol: WebPresentable, AlertPresentable, ErrorPresentable {
    func complete(on view: ReferralCrowdloanViewProtocol?)
}
