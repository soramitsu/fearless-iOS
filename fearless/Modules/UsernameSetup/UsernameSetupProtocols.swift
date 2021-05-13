import SoraFoundation

protocol UsernameSetupViewProtocol: ControllerBackedProtocol {
    func setInput(viewModel: InputViewModelProtocol)
    func setSelectedNetwork(model: SelectableViewModel<IconWithTitleViewModel>)

    func didCompleteNetworkSelection()
}

protocol UsernameSetupPresenterProtocol: AnyObject {
    func setup()
    func selectNetworkType()
    func proceed()
}

protocol UsernameSetupInteractorInputProtocol: AnyObject {
    func setup()
}

protocol UsernameSetupInteractorOutputProtocol: AnyObject {
    func didReceive(metadata: UsernameSetupMetadata)
}

protocol UsernameSetupWireframeProtocol: AlertPresentable, NetworkTypeSelectionPresentable {
    func proceed(from view: UsernameSetupViewProtocol?, model: UsernameSetupModel)
}

protocol UsernameSetupViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding() -> UsernameSetupViewProtocol?
    static func createViewForAdding() -> UsernameSetupViewProtocol?
    static func createViewForConnection(item: ConnectionItem) -> UsernameSetupViewProtocol?
    static func createViewForSwitch() -> UsernameSetupViewProtocol?
}
