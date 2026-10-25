enum ManageGroupVisibility { case on, off, mixed }

enum ManageAssetsFilter: String, CaseIterable {
    case all, shown, hidden, auto

    func accepts(_ cell: AssetManagementTableCellViewModel) -> Bool {
        switch self {
        case .all: return true
        case .shown: return !cell.hidden
        case .hidden: return cell.preference == .hidden
        case .auto: return cell.preference == .auto
        }
    }
}

typealias AssetManagementModuleCreationResult = (
    view: AssetManagementViewInput,
    input: AssetManagementModuleInput
)

protocol AssetManagementRouterInput: PresentDismissable, ErrorPresentable, SheetAlertPresentable {
    func presentResetOrderConfirmation(viewModel: SheetAlertPresentableViewModel, from view: ControllerBackedProtocol?)

    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        delegate: NetworkManagmentModuleOutput?
    )
}

protocol AssetManagementModuleInput: AnyObject {}

protocol AssetManagementModuleOutput: AnyObject {}

extension AssetManagementRouterInput {
    func presentResetOrderConfirmation(viewModel: SheetAlertPresentableViewModel, from view: ControllerBackedProtocol?) {
        present(viewModel: viewModel, from: view)
    }
}
