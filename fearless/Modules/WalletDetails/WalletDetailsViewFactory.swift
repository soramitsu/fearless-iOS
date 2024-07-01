import Foundation
import RobinHood
import SoraFoundation

final class WalletDetailsViewFactory {
    static func createView(
        flow: WalletDetailsFlow
    ) -> WalletDetailsViewProtocol {
        let chainsRepository = ChainRepositoryFactory().createRepository(
            for: NSPredicate.enabledCHain(),
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let interactor = WalletDetailsInteractor(
            flow: flow,
            chainsRepository: AnyDataProviderRepository(chainsRepository),
            operationManager: OperationManagerFacade.sharedManager,
            eventCenter: EventCenter.shared,
            repository: AccountRepositoryFactory.createRepository(),
            availableExportOptionsProvider: AvailableExportOptionsProvider()
        )

        let wireframe = WalletDetailsWireframe()

        let localizationManager = LocalizationManager.shared
        let presenter = WalletDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: WalletDetailsViewModelFactory(),
            flow: flow,
            localizationManager: localizationManager
        )
        interactor.presenter = presenter

        let view = WalletDetailsViewController(output: presenter)
        return view
    }
}
