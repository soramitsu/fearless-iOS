import Foundation

final class PolkaswapTransaktionSettingsRouter: PolkaswapTransaktionSettingsRouterInput {
    func showSelectMarket(
        from view: ControllerBackedProtocol?,
        markets: [LiquiditySourceType],
        moduleOutput: SelectMarketModuleOutput?
    ) {
        guard let module = SelectMarketAssembly.configureModule(markets: markets, moduleOutput: moduleOutput) else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }
}
