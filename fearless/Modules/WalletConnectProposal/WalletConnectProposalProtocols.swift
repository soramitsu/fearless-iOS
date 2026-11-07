import SSFModels

typealias WalletConnectProposalModuleCreationResult = (
    view: WalletConnectProposalViewInput,
    input: WalletConnectProposalModuleInput
)

protocol WalletConnectProposalRouterInput: PresentDismissable, ErrorPresentable, SheetAlertPresentable {
    func showAllDone(
        title: String,
        description: String,
        view: ControllerBackedProtocol?,
        closure: @escaping () -> Void
    )
    func showMultiSelect(
        canSelect: Bool,
        dataSource: [ChainModel],
        selectedChains: [ChainModel.Id]?,
        moduleOutput: MultiSelectNetworksModuleOutput?,
        view: ControllerBackedProtocol?
    )
}

protocol WalletConnectProposalModuleInput: AnyObject {}

protocol WalletConnectProposalModuleOutput: AnyObject {}
