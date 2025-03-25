import UIKit
import SoraFoundation
import SoraUI
import RobinHood
import SSFModels

final class WalletOptionAssembly {
    static func configureModule(
        with wallet: MetaAccountModel,
        delegate: WalletOptionModuleOutput?
    ) -> WalletOptionModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let managedMetaAccountRepository = accountRepositoryFactory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        let chainRepository = ChainRepositoryFactory().createRepository(
            for: NSPredicate.enabledCHain(),
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
