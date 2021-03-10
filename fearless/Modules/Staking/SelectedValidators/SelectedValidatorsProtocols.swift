import SoraFoundation

protocol SelectedValidatorsViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceive(viewModels: [LocalizableResource<SelectedValidatorViewModelProtocol>])
}

protocol SelectedValidatorsPresenterProtocol: class {
    func setup()

    func selectedValidatorAt(index: Int)
}

protocol SelectedValidatorsWireframeProtocol: class {
    func showInformation(about validatorInfo: SelectedValidatorInfo,
                         from view: SelectedValidatorsViewProtocol?)
}

protocol SelectedValidatorsViewFactoryProtocol: class {
    static func createView(for validators: [SelectedValidatorInfo]) -> SelectedValidatorsViewProtocol?
}
