import Foundation
import SoraFoundation
import SoraUI
import SSFModels

final class AddERC20TokenRouter: AddERC20TokenRouterInput {
    // MARK: - Private properties

    private let localizationManager: LocalizationManagerProtocol

    // MARK: - Constructors

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    // MARK: - AddERC20TokenRouterInput

    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        chainModels: [ChainModel]?,
        contextTag: Int?,
        delegate: SelectNetworkDelegate?
    ) {
        guard
            let module = SelectNetworkAssembly.configureModule(
                wallet: wallet,
                selectedChainId: selectedChainId,
                chainModels: chainModels,
                includingAllNetworks: false,
                searchTextsViewModel: nil,
                delegate: delegate,
                contextTag: contextTag,
                predicate: NSPredicate.ethereumEcosystem()
            )
        else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }
}
