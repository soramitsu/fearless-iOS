import SoraFoundation

protocol KaruraCrowdloanViewProtocol: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceiveLearnMore(viewModel: LearnMoreViewModel)
    func didReceiveReferral(viewModel: KaruraReferralViewModel)
    func didReceiveInput(viewModel: InputViewModelProtocol)
    func didReceiveShouldInputCode()
    func didReceiveShouldAgreeTerms()
}

protocol KaruraCrowdloanPresenterProtocol: AnyObject {
    func setup()
    func update(referralCode: String)
    func applyDefaultCode()
    func applyInputCode()
    func setTermsAgreed(value: Bool)
    func presentTerms()
    func presentLearnMore()
}

protocol KaruraCrowdloanWireframeProtocol: WebPresentable {}
