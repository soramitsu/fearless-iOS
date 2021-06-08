import SoraFoundation

protocol CustomValidatorListViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(with viewModel: [CustomValidatorCellViewModel])
}

protocol CustomValidatorListPresenterProtocol: AnyObject {
    func setup()
    func didSelectValidator(at index: Int)
}

protocol CustomValidatorListViewModelFactoryProtocol: AnyObject {
    func createViewModel(validators: [ElectedValidatorInfo]) -> [CustomValidatorCellViewModel]
}

protocol CustomValidatorListInteractorInputProtocol: AnyObject {}

protocol CustomValidatorListInteractorOutputProtocol: AnyObject {}

protocol CustomValidatorListWireframeProtocol: AnyObject {
    func present(
        _ validatorInfo: ValidatorInfoProtocol,
        from view: ControllerBackedProtocol?
    )
}
