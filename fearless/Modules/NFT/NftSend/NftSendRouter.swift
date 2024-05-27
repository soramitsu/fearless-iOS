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
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chain: ChainModel,
        moduleOutput: ContactsModuleOutput
    ) {
        guard let module = ContactsAssembly.configureModule(
            wallet: wallet,
            source: .nft(chain: chain),
            moduleOutput: moduleOutput
        ) else {
            return
        }
        let navigationController = FearlessNavigationController(rootViewController: module.view.controller)
        view?.controller.present(navigationController, animated: true)
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

    func showWalletManagment(
        selectedWalletId: MetaAccountId?,
        from view: ControllerBackedProtocol?,
        moduleOutput: WalletsManagmentModuleOutput?
    ) {
        guard let module = WalletsManagmentAssembly.configureModule(
            viewType: .selectYourWallet(selectedWalletId: selectedWalletId),
            shouldSaveSelected: false,
            moduleOutput: moduleOutput
        ) else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }
}
