import SoraFoundation

protocol ReferralCrowdloanViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveLearnMore(viewModel: LearnMoreViewModel)
    func didReceiveReferral(viewModel: ReferralCrowdloanViewModel)
    func didReceiveInput(viewModel: InputViewModelProtocol)
    func didReceiveShouldInputCode()
    func didReceiveShouldAgreeTerms()
}

protocol ReferralCrowdloanPresenterProtocol: AnyObject {
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
