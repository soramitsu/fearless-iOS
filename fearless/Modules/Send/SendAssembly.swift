import UIKit
import SoraFoundation
import RobinHood
import FearlessUtils

final class SendAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        initialData: SendFlowInitialData
    ) -> SendModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let operationManager = OperationManagerFacade.sharedManager
        let dependencyContainer = SendDepencyContainer(
            wallet: wallet,
            operationManager: operationManager
        )
        let repositoryFacade = SubstrateDataStorageFacade.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: repositoryFacade
        )
        let mapper: CodableCoreDataMapper<ScamInfo, CDScamInfo> =
            CodableCoreDataMapper(entityIdentifierFieldName: #keyPath(CDScamInfo.address))
        let scamRepository: CoreDataRepository<ScamInfo, CDScamInfo> =
            repositoryFacade.createRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )
        let scamServiceOperationFactory = ScamServiceOperationFactory(
            repository: AnyDataProviderRepository(scamRepository)
        )
        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: repositoryFacade
        )
        let accountInfoRepository = substrateRepositoryFactory.createChainStorageItemRepository()
        let accountInfoFetching = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            accountInfoFetching: accountInfoFetching,
            operationQueue: operationQueue,
            meta: wallet
        )
        let interactor = SendInteractor(
            wallet: wallet,
            feeProxy: ExtrinsicFeeProxy(),
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: wallet
            ),
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            operationManager: operationManager,
            scamServiceOperationFactory: scamServiceOperationFactory,
            chainAssetFetching: chainAssetFetching,
            dependencyContainer: dependencyContainer
        )
        let router = SendRouter()

        let viewModelFactory = SendViewModelFactory(iconGenerator: PolkadotIconGenerator())
        let dataValidatingFactory = SendDataValidatingFactory(presentable: router)
        let presenter = SendPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: viewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            qrParser: SubstrateQRParser(),
            logger: Logger.shared,
            wallet: wallet,
            initialData: initialData
        )

        let view = SendViewController(
            output: presenter,
            localizationManager: localizationManager
        )
        dataValidatingFactory.view = view

        return (view, presenter)
    }
}
