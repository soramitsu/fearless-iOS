import SoraFoundation

protocol RecommendedValidatorListViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(viewModel: RecommendedValidatorListViewModelProtocol)
}

protocol RecommendedValidatorListPresenterProtocol: AnyObject {
    func setup()
    func selectedValidatorAt(index: Int)
    func proceed()
}

protocol RecommendedValidatorListWireframeProtocol: AnyObject {
    func present(
        _ validatorInfo: SelectedValidatorInfo,
        from view: RecommendedValidatorListViewProtocol?
    )

    func proceed(
        from view: RecommendedValidatorListViewProtocol?,
        targets: [SelectedValidatorInfo],
        maxTargets: Int
    )
}

protocol RecommendedValidatorListViewFactoryProtocol: AnyObject {
    static func createInitiatedBondingView(
        for validators: [SelectedValidatorInfo],
        maxTargets: Int,
        with state: InitiatedBonding
    ) -> RecommendedValidatorListViewProtocol?

    static func createChangeTargetsView(
        for validators: [SelectedValidatorInfo],
        maxTargets: Int,
        with state: ExistingBonding
    ) -> RecommendedValidatorListViewProtocol?

    static func createChangeYourValidatorsView(
        for validators: [SelectedValidatorInfo],
        maxTargets: Int,
        with state: ExistingBonding
    ) -> RecommendedValidatorListViewProtocol?
}
