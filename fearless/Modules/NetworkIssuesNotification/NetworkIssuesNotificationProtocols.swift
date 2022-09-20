import Foundation
typealias NetworkIssuesNotificationModuleCreationResult = (
    view: NetworkIssuesNotificationViewInput,
    input: NetworkIssuesNotificationModuleInput
)

protocol NetworkIssuesNotificationViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: [NetworkIssuesNotificationCellViewModel])
}

protocol NetworkIssuesNotificationViewOutput: AnyObject {
    func didLoad(view: NetworkIssuesNotificationViewInput)
    func dissmis()
    func didTapCellAction(indexPath: IndexPath?)
}

protocol NetworkIssuesNotificationInteractorInput: AnyObject {
    func setup(with output: NetworkIssuesNotificationInteractorOutput)
    func markUnused(chain: ChainModel)
}

protocol NetworkIssuesNotificationInteractorOutput: AnyObject {
    func didReceiveWallet(wallet: MetaAccountModel)
    func didReceiveChainsIssues(issues: [ChainIssue])
}

protocol NetworkIssuesNotificationRouterInput: SheetAlertPresentable, AlertPresentable {
    func dismiss(view: ControllerBackedProtocol?)
    func presentAccountOptions(
        from view: ControllerBackedProtocol?,
        locale: Locale?,
        options: [MissingAccountOption],
        uniqueChainModel: UniqueChainModel,
        skipBlock: @escaping (ChainModel) -> Void
    )
    func presentNodeSelection(
        from view: ControllerBackedProtocol?,
        chain: ChainModel
    )
}

protocol NetworkIssuesNotificationModuleInput: AnyObject {}

protocol NetworkIssuesNotificationModuleOutput: AnyObject {}
