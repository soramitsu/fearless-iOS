import SoraFoundation

protocol UsernameSetupViewProtocol: ControllerBackedProtocol {
    func set(viewModel: InputViewModelProtocol)
}

protocol UsernameSetupPresenterProtocol: class {
    func setup()
    func proceed()
}

protocol UsernameSetupWireframeProtocol: AlertPresentable {
    func proceed(from view: UsernameSetupViewProtocol?, username: String)
}

protocol UsernameSetupViewFactoryProtocol: class {
	static func createView() -> UsernameSetupViewProtocol?
}
