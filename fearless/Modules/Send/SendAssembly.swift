import UIKit
import SoraFoundation
import RobinHood
import SSFUtils
import SSFModels
import Web3ContractABI
import Web3
import SoraKeystore
import SSFSigner
import SSFCrypto
import SSFExtrinsicKit
import SSFNetwork
import SSFChainRegistry
import SSFChainConnection

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
        let priceLocalSubscriber = PriceLocalStorageSubscriberImpl.shared
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
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: operationQueue
        )
        let addressChainDefiner = AddressChainDefiner(
            operationManager: operationManager,
            chainModelRepository: AnyDataProviderRepository(chainRepository),
            wallet: wallet
        )
        let runtimeMetadataRepository: CoreDataRepository<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            SubstrateDataStorageFacade.shared.createRepository()
        let interactor = SendInteractor(
            feeProxy: ExtrinsicFeeProxy(),
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: wallet
            ),
            priceLocalSubscriber: priceLocalSubscriber,
            operationManager: operationManager,
            scamServiceOperationFactory: scamServiceOperationFactory,
            chainAssetFetching: chainAssetFetching,
            dependencyContainer: dependencyContainer,
            addressChainDefiner: addressChainDefiner,
            runtimeItemRepository: AnyDataProviderRepository(runtimeMetadataRepository),
            operationQueue: OperationQueue()
        )
        let router = SendRouter()

        let viewModelFactory = SendViewModelFactory(iconGenerator: UniversalIconGenerator())
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
            initialData: initialData,
            output: presenter,
            localizationManager: localizationManager
        )
        dataValidatingFactory.view = view

        return (view, presenter)
    }
}
