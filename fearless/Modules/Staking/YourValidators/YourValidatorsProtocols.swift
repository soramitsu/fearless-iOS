import SoraFoundation

protocol YourValidatorsViewProtocol: ControllerBackedProtocol {
    func reload(state: YourValidatorsViewState)
}

protocol YourValidatorsPresenterProtocol: AnyObject {
    func setup()
    func didSelectValidator(viewModel: YourValidatorsModel)
    func changeValidators()
}

protocol YourValidatorsInteractorInputProtocol: AnyObject {
    func setup()
    func refresh()
}

protocol YourValidatorsInteractorOutputProtocol: AnyObject {
    func didReceiveValidators(result: Result<YourValidatorsModel?, Error>)
    func didReceiveController(result: Result<AccountItem?, Error>)
    func didReceiveElectionStatus(result: Result<ElectionStatus, Error>)
}

protocol YourValidatorsWireframeProtocol: AnyObject {}

protocol YourValidatorsViewFactoryProtocol: AnyObject {
    static func createView() -> YourValidatorsViewProtocol?
}
