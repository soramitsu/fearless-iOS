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

    func presentFilters(
        with filters: [FilterSet],
        from view: ControllerBackedProtocol?,
        moduleOutput: NftFiltersModuleOutput?
    ) {
        guard let view = view, let filtersViewController = NftFiltersAssembly.configureModule(
            filters: filters,
            moduleOutput: moduleOutput
        )?.controller else {
            return
        }

        view.controller.present(filtersViewController, animated: true, completion: nil)
    }
}
