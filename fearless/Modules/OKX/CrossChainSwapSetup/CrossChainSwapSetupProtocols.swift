import SSFModels
import Foundation

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
        selectedChainAsset: ChainAsset?,
        filter: ((ChainAsset) throws -> Bool)?
    )

    func presentConfirm(
        crossChainSwapParameters: CrossChainSwapParameters,
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
    
    func presentFundsPermission(
        mode: CrossChainFundsPermissionMode,
        crossChainSwapParameters: CrossChainSwapParameters,
        from view: ControllerBackedProtocol?
    )
}

protocol CrossChainSwapSetupModuleInput: AnyObject {
    func didSelect(sourceChainAsset: ChainAsset?)
}

protocol CrossChainSwapSetupModuleOutput: AnyObject {
    func didSwitchToPolkaswap(with chainAsset: ChainAsset?)
}
