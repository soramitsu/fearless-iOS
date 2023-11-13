import Foundation

final class NftCollectionRouter: NftCollectionRouterInput {
    func openNftDetails(nft: NFT, wallet: MetaAccountModel, address: String, from view: ControllerBackedProtocol?) {
        let nftDetailsModule = NftDetailsAssembly.configureModule(nft: nft, wallet: wallet, address: address)

        guard let controller = nftDetailsModule?.view.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }
}
