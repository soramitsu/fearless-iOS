import SoraFoundation

protocol UsernameSetupViewProtocol: ControllerBackedProtocol {
    func bindUsername(viewModel: SelectableViewModel<InputViewModelProtocol>)
    func bindUniqueChain(viewModel: UniqueChainViewModel)
}

protocol UsernameSetupPresenterProtocol: AnyObject {
    func didLoad(view: UsernameSetupViewProtocol)
    func proceed()
}

protocol UsernameSetupWireframeProtocol: SheetAlertPresentable, NetworkTypeSelectionPresentable {
    func proceed(from view: UsernameSetupViewProtocol?, flow: AccountCreateFlow, model: UsernameSetupModel)
}

protocol UsernameSetupViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding(flow: AccountCreateFlow) -> UsernameSetupViewProtocol?
    static func createViewForAdding() -> UsernameSetupViewProtocol?
    static func createViewForSwitch() -> UsernameSetupViewProtocol?
}

extension UsernameSetupViewFactoryProtocol {
    static func createViewForOnboarding() -> UsernameSetupViewProtocol? {
        Self.createViewForOnboarding(flow: .wallet)
    }
}
