import Foundation

final class MainNftContainerRouter: MainNftContainerRouterInput {
    func showCollection(
        _ collection: NFTCollection,
        wallet: MetaAccountModel,
        address: String,
        from view: ControllerBackedProtocol?
    ) {
        let collectionModule = NftCollectionAssembly.configureModule(collection: collection, wallet: wallet, address: address)
        guard let controller = collectionModule?.view.controller else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: controller)

        view?.controller.navigationController?.present(navigationController, animated: true)
    }
}
