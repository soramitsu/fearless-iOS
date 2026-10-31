import SoraFoundation
import SSFModels

protocol WalletDetailsViewOutputProtocol {
    func didLoad(ui: WalletDetailsViewProtocol)
    func didTapCloseButton()
    func didTapExportButton()
    func showActions(for chain: ChainModel, account: ChainAccountResponse?)
    func searchTextDidChanged(_ text: String?)
}

protocol WalletDetailsViewProtocol: ControllerBackedProtocol, HiddableBarWhenPushed {
    func didReceive(state: WalletDetailsViewState)
    func didReceive(locale: Locale)
}

protocol WalletDetailsInteractorInputProtocol: AnyObject {
    func setup()
    func getAvailableExportOptions(for chainAccount: ChainAccountInfo)
    func markUnused(chain: ChainModel)
    func selectChainAccount(_ selection: ChainAccountSelection, chain: ChainModel)
    func switchToPasswordAccount(_ account: UniversalWalletNoPasswordAccount)
}

protocol WalletDetailsInteractorOutputProtocol: AnyObject {
    func didReceive(chains: [ChainModel])
    func didReceiveExportOptions(options: [ExportOption], for chainAccount: ChainAccountInfo)
    func didReceive(error: Error)
    func didReceive(updatedFlow: WalletDetailsFlow)
    func didReceive(storedChainAccounts: [ChainAccountModel])
    /// Universal accounts the wallet's password does not protect yet.
    func didReceive(noPasswordAccounts: [UniversalWalletNoPasswordAccount])
    func didReceive(
        switchOutcomes: [UniversalWalletSlot: UniversalWalletSwitchOutcome],
        for accounts: [UniversalWalletNoPasswordAccount]
    )
}

protocol WalletDetailsWireframeProtocol: ErrorPresentable,
    SheetAlertPresentable,
    ModalAlertPresenting,
    AuthorizationPresentable,
    AnyDismissable {
    func presentActions(
        from view: ControllerBackedProtocol?,
        items: [ChainAction],
        chain: ChainModel,
        callback: @escaping ModalPickerSelectionCallback
    )

    func showExport(
        flow: ExportFlow,
        options: [ExportOption],
        locale: Locale?,
        from view: ControllerBackedProtocol?
    )

    func presentNodeSelection(
        from view: ControllerBackedProtocol?,
        chain: ChainModel
    )
    func present(
        from view: ControllerBackedProtocol,
        url: URL
    )

    func showUniqueChainSourceSelection(
        from view: ControllerBackedProtocol?,
        items: [ReplaceChainOption],
        callback: @escaping ModalPickerSelectionCallback
    )

    func showCreate(uniqueChainModel: UniqueChainModel, from view: ControllerBackedProtocol?)
    func showImport(uniqueChainModel: UniqueChainModel, from view: ControllerBackedProtocol?)

    func presentAccountOptions(
        from view: ControllerBackedProtocol?,
        locale: Locale?,
        options: [MissingAccountOption],
        uniqueChainModel: UniqueChainModel,
        skipBlock: @escaping (ChainModel) -> Void
    )
}
