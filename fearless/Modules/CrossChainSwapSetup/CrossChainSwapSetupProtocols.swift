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

    func presentLiquiditySourcesSelection(
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?,
        moduleOutput: DexListModuleOutput?,
        selectedDexIds: [String]?
    )

    func presentBridgeSelection(
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        amount: String,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?,
        moduleOutput: BridgeListModuleOutput?,
        selectedSort: UInt8
    )
}

protocol CrossChainSwapSetupModuleInput: AnyObject {
    func didSelect(sourceChainAsset: ChainAsset?)
}

protocol CrossChainSwapSetupModuleOutput: AnyObject {
    func didSwitchToPolkaswap(with chainAsset: ChainAsset?)
}
