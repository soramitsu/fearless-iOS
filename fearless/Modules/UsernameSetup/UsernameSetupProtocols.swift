import SoraFoundation

protocol UsernameSetupViewProtocol: ControllerBackedProtocol {
    func setInput(viewModel: InputViewModelProtocol)
}

protocol UsernameSetupPresenterProtocol: AnyObject {
    func setup()
    func proceed()
}

protocol UsernameSetupWireframeProtocol: AlertPresentable, NetworkTypeSelectionPresentable {
    func proceed(from view: UsernameSetupViewProtocol?, model: UsernameSetupModel)
}

protocol UsernameSetupViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding() -> UsernameSetupViewProtocol?
    static func createViewForAdding() -> UsernameSetupViewProtocol?
    static func createViewForSwitch() -> UsernameSetupViewProtocol?
}
