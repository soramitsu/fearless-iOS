import SoraFoundation

protocol UsernameSetupViewProtocol: ControllerBackedProtocol {
    func set(viewModel: InputViewModelProtocol)
}

protocol UsernameSetupPresenterProtocol: AnyObject {
    func setup()
    func proceed()
}

protocol UsernameSetupWireframeProtocol: AlertPresentable {
    func proceed(from view: UsernameSetupViewProtocol?, username: String)
}

protocol UsernameSetupViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding() -> UsernameSetupViewProtocol?
    static func createViewForAdding() -> UsernameSetupViewProtocol?
    static func createViewForConnection(item: ConnectionItem) -> UsernameSetupViewProtocol?
    static func createViewForSwitch() -> UsernameSetupViewProtocol?
}
