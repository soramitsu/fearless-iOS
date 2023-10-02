import Foundation
import SSFModels

final class NftSendRouter: NftSendRouterInput {
    func presentScan(
        from view: ControllerBackedProtocol?,
        moduleOutput: ScanQRModuleOutput
    ) {
        guard let module = ScanQRAssembly.configureModule(moduleOutput: moduleOutput) else {
            return
        }

        view?.controller.present(module.view.controller, animated: true, completion: nil)
    }

    func presentHistory(
        from _: ControllerBackedProtocol?,
        wallet _: MetaAccountModel,
        chain _: ChainModel,
        moduleOutput _: ContactsModuleOutput
    ) {
//        guard let module = ContactsAssembly.configureModule(
//            wallet: wallet,
//            chainAsset: chainAsset,
//            moduleOutput: moduleOutput
//        ) else {
//            return
//        }
//        let navigationController = FearlessNavigationController(rootViewController: module.view.controller)
//        view?.controller.present(navigationController, animated: true)
    }

    func presentConfirm(
        nft: NFT,
        receiver: String,
        scamInfo: ScamInfo?,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        let module = NftSendConfirmAssembly.configureModule(wallet: wallet, nft: nft, receiverAddress: receiver, scamInfo: scamInfo)

        guard let controller = module?.view.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }
}
