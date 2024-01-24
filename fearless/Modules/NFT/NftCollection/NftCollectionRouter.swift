import Foundation

final class NftCollectionRouter: NftCollectionRouterInput {
    func openNftDetails(nft: NFT, type: NftType, wallet: MetaAccountModel, address: String, from view: ControllerBackedProtocol?) {
        let nftDetailsModule = NftDetailsAssembly.configureModule(
            nft: nft,
            wallet: wallet,
            address: address,
            type: type
        )

        guard let controller = nftDetailsModule?.view.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }

    func openSend(nft: NFT, wallet: MetaAccountModel, from view: ControllerBackedProtocol?) {
        let sendModule = NftSendAssembly.configureModule(nft: nft, wallet: wallet)

        guard let controller = sendModule?.view.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }
}
