import SoraFoundation

protocol SelectValidatorsViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(with viewModel: [SelectValidatorsCellViewModel])
}

protocol SelectValidatorsPresenterProtocol: AnyObject {
    func setup()
}

protocol SelectValidatorsViewModelFactoryProtocol: AnyObject {
    func createViewModel(validators: [ElectedValidatorInfo]) -> [SelectValidatorsCellViewModel]
}

protocol SelectValidatorsInteractorInputProtocol: AnyObject {}

protocol SelectValidatorsInteractorOutputProtocol: AnyObject {}

protocol SelectValidatorsWireframeProtocol: AnyObject {}
