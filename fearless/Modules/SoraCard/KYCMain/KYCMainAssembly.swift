import UIKit
import SoraFoundation
import RobinHood

final class KYCMainAssembly {
    static func configureModule(data: SCKYCUserDataModel, wallet: MetaAccountModel) -> KYCMainModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated

        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )
        let accountInfoRepository = substrateRepositoryFactory.createAccountInfoStorageItemRepository()
        let accountInfoFetching = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            accountInfoFetching: accountInfoFetching,
            operationQueue: operationQueue,
            meta: wallet
        )
        let repositoryFacade = SubstrateDataStorageFacade.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: repositoryFacade
        )

        let interactor = KYCMainInteractor(
            data: data,
            wallet: wallet,
            service: .shared,
            chainAssetFetching: chainAssetFetching,
            accountInfoFetching: accountInfoFetching,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory
        )
        let router = KYCMainRouter()

        let presenter = KYCMainPresenter(
            interactor: interactor,
            router: router,
            viewModelFactory: KYCMainViewModelFactory(),
            localizationManager: localizationManager
        )

        let view = KYCMainViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
