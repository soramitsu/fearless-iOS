import SoraFoundation

protocol SelectedValidatorListViewProtocol: ControllerBackedProtocol, Localizable {
    func didReload(_ viewModel: SelectedValidatorListViewModel)
    func didChangeViewModel(
        _ viewModel: SelectedValidatorListViewModel,
        byRemovingItemAt index: Int
    )
}

protocol SelectedValidatorListDelegate: AnyObject {
    func didRemove(_ validator: ElectedValidatorInfo)
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

protocol SelectedValidatorListViewFactoryProtocol {
    static func createInitiatedBondingView(
        for validators: [ElectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate,
        with state: InitiatedBonding
    ) -> SelectedValidatorListViewProtocol?

    static func createChangeTargetsView(
        for validators: [ElectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate,
        with state: ExistingBonding
    ) -> SelectedValidatorListViewProtocol?

    static func createChangeYourValidatorsView(
        for validators: [ElectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate,
        with state: ExistingBonding
    ) -> SelectedValidatorListViewProtocol?
}
