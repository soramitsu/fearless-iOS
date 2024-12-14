import SSFModels

typealias CrossChainSwapConfirmModuleCreationResult = (
    view: CrossChainSwapConfirmViewInput,
    input: CrossChainSwapConfirmModuleInput
)

protocol CrossChainSwapConfirmRouterInput: AnyObject, PushDismissable, SheetAlertPresentable, ErrorPresentable, BaseErrorPresentable, AllDonePresentable {
    func presentStatusTrackingScreen(
        transaction: AssetTransactionData,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    )
}

protocol CrossChainSwapConfirmModuleInput: AnyObject {}

protocol CrossChainSwapConfirmModuleOutput: AnyObject {}
