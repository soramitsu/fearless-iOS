import SSFModels

typealias CrossChainSwapSetupModuleCreationResult = (
    view: CrossChainSwapSetupViewInput,
    input: CrossChainSwapSetupModuleInput
)

protocol CrossChainSwapSetupRouterInput: AnyObject, PresentDismissable, SheetAlertPresentable, ErrorPresentable, BaseErrorPresentable {
    func showSelectAsset(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        output: SelectAssetModuleOutput,
        flow: MultichainChainFetchingFlow,
        selectedChainAsset: ChainAsset?
    )

    func presentConfirm(
        swapFromChainAsset: ChainAsset,
        swapToChainAsset: ChainAsset,
        wallet: MetaAccountModel,
        swap: CrossChainSwap,
        from view: ControllerBackedProtocol?
    )
}

protocol CrossChainSwapSetupModuleInput: AnyObject {
    func didSelect(sourceChainAsset: ChainAsset?)
}

protocol CrossChainSwapSetupModuleOutput: AnyObject {
    func didSwitchToPolkaswap(with chainAsset: ChainAsset?)
}
