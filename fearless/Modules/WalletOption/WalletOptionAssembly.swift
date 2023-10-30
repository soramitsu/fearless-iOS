import UIKit
import SoraFoundation
import SoraUI
import RobinHood

final class WalletOptionAssembly {
    static func configureModule(
        with wallet: ManagedMetaAccountModel,
        delegate: WalletOptionModuleOutput?
    ) -> WalletOptionModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let managedMetaAccountRepository = accountRepositoryFactory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository)
        )

        let walletConnectModelFactory = WalletConnectModelFactoryImpl()
        let walletConnectDisconnectService = WalletConnectDisconnectServiceImpl(
            walletConnectModelFactory: walletConnectModelFactory,
            chainAssetFetcher: chainAssetFetching
        )

        let interactor = WalletOptionInteractor(
            wallet: wallet,
            metaAccountRepository: AnyDataProviderRepository(managedMetaAccountRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            moduleOutput: delegate,
            walletConnectDisconnectService: walletConnectDisconnectService
        )
        let router = WalletOptionRouter()

        let presenter = WalletOptionPresenter(
            wallet: wallet,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = WalletOptionViewController(
            output: presenter,
            localizationManager: localizationManager
        )
        view.modalPresentationStyle = .custom

        let factory = ModalSheetBlurPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.fearlessBlur
        )
        view.modalTransitioningFactory = factory

        return (view, presenter)
    }
}
