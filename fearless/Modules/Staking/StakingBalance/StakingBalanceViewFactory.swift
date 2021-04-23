import SoraFoundation
import SoraKeystore
import RobinHood
import FearlessUtils

struct StakingBalanceViewFactory {
    static func createView() -> StakingBalanceViewProtocol? {
        guard let interactor = createInteractor() else { return nil }
        let wireframe = StakingBalanceWireframe()
        let presenter = StakingBalancePresenter(
            interactor: interactor,
            wireframe: wireframe
        )
        interactor.presenter = presenter

        let viewController = StakingBalanceViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
        presenter.view = viewController

        return viewController
    }

    private static func createInteractor() -> StakingBalanceInteractor? {
        guard let selectedAccount = SettingsManager.shared.selectedAccount else {
            return nil
        }

        let networkType = SettingsManager.shared.selectedConnection.type
        guard let localStorageIdFactory = try? ChainStorageIdFactory(chain: networkType.chain) else { return nil }
        let localStorageRequestFactory = LocalStorageRequestFactory(
            remoteKeyFactory: StorageKeyFactory(),
            localKeyFactory: localStorageIdFactory
        )

        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let chainStorage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            substrateStorageFacade.createRepository()

        let interactor = StakingBalanceInteractor(
            accountAddress: selectedAccount.address,
            runtimeCodingService: RuntimeRegistryFacade.sharedService,
            chainStorage: AnyDataProviderRepository(chainStorage),
            localStorageRequestFactory: localStorageRequestFactory,
            operationManager: OperationManagerFacade.sharedManager
        )
        return interactor
    }
}
