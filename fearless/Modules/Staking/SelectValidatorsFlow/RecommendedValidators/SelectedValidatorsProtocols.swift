import SoraFoundation

protocol SelectedValidatorsViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(viewModel: SelectedValidatorsViewModelProtocol)
}

protocol SelectedValidatorsPresenterProtocol: AnyObject {
    func setup()
    func selectedValidatorAt(index: Int)
    func proceed()
}

protocol SelectedValidatorsWireframeProtocol: AnyObject {
    func showInformation(
        about validatorInfo: SelectedValidatorInfo,
        from view: SelectedValidatorsViewProtocol?
    )

    func proceed(
        from view: SelectedValidatorsViewProtocol?,
        targets: [SelectedValidatorInfo],
        maxTargets: Int
    )
}

protocol SelectedValidatorsViewFactoryProtocol: AnyObject {
    static func createInitiatedBondingView(
        for validators: [SelectedValidatorInfo],
        maxTargets: Int,
        with state: InitiatedBonding
    ) -> SelectedValidatorsViewProtocol?

    static func createChangeTargetsView(
        for validators: [SelectedValidatorInfo],
        maxTargets: Int,
        with state: ExistingBonding
    ) -> SelectedValidatorsViewProtocol?

    static func createChangeYourValidatorsView(
        for validators: [SelectedValidatorInfo],
        maxTargets: Int,
        with state: ExistingBonding
    ) -> SelectedValidatorsViewProtocol?
}
