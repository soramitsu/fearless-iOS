import WalletConnectSign
typealias WalletConnectActiveSessionsModuleCreationResult = (
    view: WalletConnectActiveSessionsViewInput,
    input: WalletConnectActiveSessionsModuleInput
)

protocol WalletConnectActiveSessionsRouterInput: PresentDismissable, SheetAlertPresentable, ErrorPresentable {
    func showSession(
        _ session: Session,
        view: ControllerBackedProtocol?
    )
    func showScaner(
        output: ScanQRModuleOutput,
        view: ControllerBackedProtocol?
    )
}

protocol WalletConnectActiveSessionsModuleInput: AnyObject {}

protocol WalletConnectActiveSessionsModuleOutput: AnyObject {}
