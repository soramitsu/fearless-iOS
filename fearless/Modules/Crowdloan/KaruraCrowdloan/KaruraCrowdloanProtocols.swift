protocol KaruraCrowdloanViewProtocol: ControllerBackedProtocol {
    func didReceiveLearnMore(viewModel: LearnMoreViewModel)
    func didReceiveBonus(viewModel: String)
}

protocol KaruraCrowdloanPresenterProtocol: AnyObject {
    func setup()
}

protocol KaruraCrowdloanInteractorInputProtocol: AnyObject {}

protocol KaruraCrowdloanInteractorOutputProtocol: AnyObject {}

protocol KaruraCrowdloanWireframeProtocol: AnyObject {}
