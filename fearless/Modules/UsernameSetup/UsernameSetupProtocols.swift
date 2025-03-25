import SoraFoundation

protocol UsernameSetupViewProtocol: ControllerBackedProtocol {
    func bindUsername(viewModel: SelectableViewModel<InputViewModelProtocol>)
    func bindUniqueChain(viewModel: UniqueChainViewModel)
}

protocol UsernameSetupPresenterProtocol: AnyObject {
    func didLoad(view: UsernameSetupViewProtocol)
    func proceed()
}

protocol UsernameSetupWireframeProtocol: SheetAlertPresentable {
    func proceed(
        from view: UsernameSetupViewProtocol?,
        flow: AccountCreateFlow,
        model: UsernameSetupModel,
        ecosystem: AccountCreateEcosystem
    )
}

protocol UsernameSetupViewFactoryProtocol: AnyObject {
    static func createViewForOnboarding(flow: AccountCreateFlow, ecosystem: AccountCreateEcosystem) -> UsernameSetupViewProtocol?
    static func createViewForAdding(ecosystem: AccountCreateEcosystem) -> UsernameSetupViewProtocol?
    static func createViewForSwitch(ecosystem: AccountCreateEcosystem) -> UsernameSetupViewProtocol?
}

extension UsernameSetupViewFactoryProtocol {
    static func createViewForOnboarding(ecosystem: AccountCreateEcosystem) -> UsernameSetupViewProtocol? {
        Self.createViewForOnboarding(flow: .wallet, ecosystem: ecosystem)
    }
}
