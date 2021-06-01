import SoraFoundation

protocol KaruraCrowdloanViewProtocol: ControllerBackedProtocol {
    func didReceiveLearnMore(viewModel: LearnMoreViewModel)
    func didReceiveReferral(viewModel: KaruraReferralViewModel)
    func didReceiveInput(viewModel: InputViewModelProtocol)
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
