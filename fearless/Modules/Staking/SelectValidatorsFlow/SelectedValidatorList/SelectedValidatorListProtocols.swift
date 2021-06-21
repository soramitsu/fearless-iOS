import SoraFoundation

protocol SelectedValidatorListViewProtocol: ControllerBackedProtocol, Localizable {
    func updateViewModel(_ viewModel: SelectedValidatorListViewModel)
    func reload(_ viewModel: SelectedValidatorListViewModel)
    func didRemoveItem(at index: Int)
}

protocol SelectedValidatorListPresenterProtocol: AnyObject {
    func setup()
    func didSelectValidator(at index: Int)
    func removeItem(at index: Int)
    func proceed()
    func dismiss()
}

protocol SelectedValidatorListViewModelFactoryProtocol: AnyObject {
    func createViewModel(
        from validators: [ElectedValidatorInfo],
        totalValidatorsCount: Int,
        locale: Locale
    ) -> SelectedValidatorListViewModel
}

protocol SelectedValidatorListInteractorInputProtocol: AnyObject {}

protocol SelectedValidatorListInteractorOutputProtocol: AnyObject {}

protocol SelectedValidatorListWireframeProtocol: AlertPresentable, ErrorPresentable {
    func present(
        _ validatorInfo: ValidatorInfoProtocol,
        from view: ControllerBackedProtocol?
    )

    func proceed(
        from view: SelectedValidatorListViewProtocol?,
        targets: [SelectedValidatorInfo],
        maxTargets: Int
    )

    func dismiss(_ view: ControllerBackedProtocol?)
}

extension SelectedValidatorListViewProtocol {}
