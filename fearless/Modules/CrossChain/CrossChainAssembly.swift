import UIKit
import SoraFoundation
import SSFUtils
import RobinHood
import SSFXCM
import SSFNetwork
import SSFModels

final class CrossChainAssembly {
    static func configureModule(
        with chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) -> CrossChainModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let priceLocalSubscriber = PriceLocalStorageSubscriberImpl.shared

        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedMetaAccount: wallet
        )

        let chainRepository = ChainRepositoryFactory().createRepository(
            for: NSPredicate.enabledCHain(),
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: operationQueue
        )

        let depsContainer = CrossChainDepsContainer(wallet: wallet)
        let runtimeMetadataRepository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        let addressChainDefiner = AddressChainDefiner(
            operationManager: OperationManagerFacade.sharedManager,
            chainModelRepository: AnyDataProviderRepository(chainRepository),
            wallet: wallet
        )

        let existentialDepositService = ExistentialDepositService(
            operationManager: OperationManagerFacade.sharedManager,
            chainRegistry: chainRegistry,
            chainId: chainAsset.chain.chainId
        )
        let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId)
        let storageRequestPerformer: StorageRequestPerformer? = runtimeService.flatMap {
            guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
                return nil
            }

            return StorageRequestPerformerDefault(runtimeService: $0, connection: connection)
        }

        let interactor = CrossChainInteractor(
            chainAssetFetching: chainAssetFetching,
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            priceLocalSubscriber: priceLocalSubscriber,
            depsContainer: depsContainer,
            runtimeItemRepository: AnyDataProviderRepository(runtimeMetadataRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared,
            wallet: wallet,
            addressChainDefiner: addressChainDefiner,
            existentialDepositService: existentialDepositService,
            storageRequestPerformer: storageRequestPerformer
        )
        let router = CrossChainRouter()
        let dataValidatingFactory = SendDataValidatingFactory(presentable: router)
        let iconGenerator = UniversalIconGenerator()
        let viewModelFactory = CrossChainViewModelFactory(iconGenerator: iconGenerator)
        let presenter = CrossChainPresenter(
            originChainAsset: chainAsset,
            wallet: wallet,
            viewModelFactory: viewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            logger: Logger.shared,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = CrossChainViewController(
            output: presenter,
            localizationManager: localizationManager
        )
        dataValidatingFactory.view = view

        return (view, presenter)
    }
}
