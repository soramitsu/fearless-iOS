import SSFModels

typealias CrossChainTxTrackingModuleCreationResult = (
    view: CrossChainTxTrackingViewInput,
    input: CrossChainTxTrackingModuleInput
)

protocol CrossChainTxTrackingRouterInput: AnyObject, AnyDismissable, ApplicationStatusPresentable, SharingPresentable {
    func presentHistoryDetails(
        chainAsset: ChainAsset,
        transaction: AssetTransactionData,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    )
}

protocol CrossChainTxTrackingModuleInput: AnyObject {}

protocol CrossChainTxTrackingModuleOutput: AnyObject {}
