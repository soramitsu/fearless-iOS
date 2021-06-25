import SoraFoundation

protocol ValidatorSearchWireframeProtocol: AlertPresentable {
    func present(
        _ validatorInfo: ValidatorInfoProtocol,
        from view: ControllerBackedProtocol?
    )

    func close(_ view: ControllerBackedProtocol?)
}

protocol ValidatorSearchDelegate: AnyObject {
    func didUpdate(
        _ validators: [ElectedValidatorInfo],
        selectedValidatos: [ElectedValidatorInfo]
    )
}

protocol ValidatorSearchViewProtocol: ControllerBackedProtocol, Localizable {
    func didReload(_ viewModel: ValidatorSearchViewModel)
    func didReset()
}

protocol ValidatorSearchInteractorInputProtocol {
    func setup()
}

protocol ValidatorSearchInteractorOutputProtocol {}

protocol ValidatorSearchPresenterProtocol: Localizable {
    func setup()
    func changeValidatorSelection(at index: Int)
    func search(for textEntry: String)
    func didSelectValidator(at index: Int)
    func applyChanges()
}

protocol ValidatorSearchViewFactoryProtocol {
    static func createView(
        with validators: [ElectedValidatorInfo],
        selectedValidators: [ElectedValidatorInfo],
        delegate: ValidatorSearchDelegate?
    ) -> ValidatorSearchViewProtocol?
}

protocol ValidatorSearchViewModelFactoryProtocol {
    func createViewModel(
        from validators: [ElectedValidatorInfo],
        selectedValidators: [ElectedValidatorInfo],
        locale: Locale
    ) -> ValidatorSearchViewModel
}
