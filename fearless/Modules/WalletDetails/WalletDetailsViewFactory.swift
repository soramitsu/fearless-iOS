import Foundation
import RobinHood
import SoraFoundation
import SoraKeystore

final class WalletDetailsViewFactory {
    static func createView(
        flow: WalletDetailsFlow
    ) -> WalletDetailsViewProtocol {
        // Disabled chains too: the presenter keeps those where the wallet has its own account.
        let chainsRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let interactor = WalletDetailsInteractor(
            flow: flow,
            chainsRepository: AnyDataProviderRepository(chainsRepository),
            operationManager: OperationManagerFacade.sharedManager,
            eventCenter: EventCenter.shared,
            repository: AccountRepositoryFactory.createRepository(),
            availableExportOptionsProvider: AvailableExportOptionsProvider(),
            walletRecordsInspector: AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
                .createStoredWalletRecordsInspector(),
            walletRecordsNoticeTracker: StoredWalletRecordsNoticeTracker(settings: SettingsManager.shared),
            selectedWalletSettings: SelectedWalletSettings.shared
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
