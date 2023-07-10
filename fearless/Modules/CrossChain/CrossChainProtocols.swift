import Foundation
import SSFXCM
import SSFModels

typealias CrossChainModuleCreationResult = (
    view: CrossChainViewInput,
    input: CrossChainModuleInput
)

protocol CrossChainRouterInput: PresentDismissable, SheetAlertPresentable, ErrorPresentable, BaseErrorPresentable {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        chainModels: [ChainModel]?,
        contextTag: Int?,
        delegate: SelectNetworkDelegate?
    )

    func showSelectAsset(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset]?,
        selectedAssetId: AssetModel.Id?,
        output: SelectAssetModuleOutput
    )

    func showConfirmation(
        from view: ControllerBackedProtocol?,
        data: CrossChainConfirmationData,
        xcmServices: XcmExtrinsicServices
    )

    func presentScan(
        from view: ControllerBackedProtocol?,
        moduleOutput: ScanQRModuleOutput
    )

    func presentHistory(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        moduleOutput: ContactsModuleOutput
    )

    func showWalletManagment(
        selectedWalletId: MetaAccountId?,
        from view: ControllerBackedProtocol?,
        moduleOutput: WalletsManagmentModuleOutput?
    )
}

protocol CrossChainModuleInput: AnyObject {}

protocol CrossChainModuleOutput: AnyObject {}
