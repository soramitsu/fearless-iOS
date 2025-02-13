typealias CrossChainFundsPermissionModuleCreationResult = (
    view: CrossChainFundsPermissionViewInput,
    input: CrossChainFundsPermissionModuleInput
)

protocol CrossChainFundsPermissionRouterInput: AnyObject, AnyDismissable, SheetAlertPresentable, ErrorPresentable {
    func presentConfirm(
        crossChainSwapParameters: CrossChainSwapParameters,
        approveTxHash: String?,
        from view: ControllerBackedProtocol?
    )
}

protocol CrossChainFundsPermissionModuleInput: AnyObject {}

protocol CrossChainFundsPermissionModuleOutput: AnyObject {}
