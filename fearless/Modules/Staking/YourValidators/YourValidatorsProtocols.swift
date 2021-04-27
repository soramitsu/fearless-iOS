import SoraFoundation

protocol YourValidatorsViewProtocol: ControllerBackedProtocol {
    func reload(state: YourValidatorsViewState)
}

protocol YourValidatorsPresenterProtocol: AnyObject {
    func setup()
}

protocol YourValidatorsInteractorInputProtocol: AnyObject {
    func setup()
}

protocol YourValidatorsInteractorOutputProtocol: AnyObject {
    func didReceiveValidators(result: Result<YourValidatorsModel?, Error>)
    func didReceiveElectionStatus(result: Result<ElectionStatus, Error>)
}

protocol YourValidatorsWireframeProtocol: AnyObject {}

protocol YourValidatorsViewFactoryProtocol: AnyObject {
    static func createView() -> YourValidatorsViewProtocol?
}
