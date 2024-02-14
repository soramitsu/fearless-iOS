import Foundation

final class NftDetailsRouter: NftDetailsRouterInput, SharingPresentable {
    func openSend(nft: NFT, wallet: MetaAccountModel, from view: ControllerBackedProtocol?) {
        let sendModule = NftSendAssembly.configureModule(nft: nft, wallet: wallet)

        guard let controller = sendModule?.view.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }
}
