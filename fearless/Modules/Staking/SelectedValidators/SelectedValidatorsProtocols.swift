import SoraFoundation

protocol SelectedValidatorsViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(viewModel: SelectedValidatorsViewModelProtocol)
}

protocol SelectedValidatorsPresenterProtocol: AnyObject {
    func setup()

    func selectedValidatorAt(index: Int)
}

protocol SelectedValidatorsWireframeProtocol: AnyObject {
    func showInformation(
        about validatorInfo: SelectedValidatorInfo,
        from view: SelectedValidatorsViewProtocol?
    )
}

protocol SelectedValidatorsViewFactoryProtocol: AnyObject {
    static func createView(
        for validators: [SelectedValidatorInfo],
        maxTargets: Int
    ) -> SelectedValidatorsViewProtocol?
}
