import Foundation
import SSFModels

final class AssetNetworksRouter: AssetNetworksRouterInput {
    func showDetails(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset
    ) {
        guard let chainAssetView = WalletChainAccountDashboardViewFactory.createDetailsView(
            chainAsset: chainAsset
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            chainAssetView.controller,
            animated: true
        )
    }

    func showFilters(
        filters: [FilterSet],
        moduleOutput: FiltersModuleOutput?,
        from view: ControllerBackedProtocol?
    ) {
        let module = FiltersViewFactory.createView(filters: filters, moduleOutput: moduleOutput)

        guard let filterView = module?.controller else {
            return
        }

        view?.controller.present(filterView, animated: true)
    }
}
