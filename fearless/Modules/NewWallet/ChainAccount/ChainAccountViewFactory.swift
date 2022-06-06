import Foundation
import SoraFoundation
import FearlessUtils
import RobinHood
import SoraKeystore

struct ChainAccountModule {
    let view: ChainAccountViewProtocol?
    let moduleInput: ChainAccountModuleInput?
}

enum ChainAccountViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        selectedMetaAccount: MetaAccountModel,
        moduleOutput: ChainAccountModuleOutput?
    ) -> ChainAccountModule? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let operationManager = OperationManagerFacade.sharedManager

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let eventCenter = EventCenter.shared

        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        let storage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        var subscriptionContainer: StorageSubscriptionContainer?

        let localStorageIdFactory = LocalStorageKeyFactory()
        if let address = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.toAddress(),
           let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId,
           let accountStorageKey = try? StorageKeyFactory().accountInfoKeyForId(accountId),
           let localStorageKey = try? localStorageIdFactory.createKey(
               from: accountStorageKey,
               key: chainAsset.chain.chainId
           ) {
            let storageRequestFactory = StorageRequestFactory(
                remoteFactory: StorageKeyFactory(),
                operationManager: OperationManagerFacade.sharedManager
            )

            let contactOperationFactory: WalletContactOperationFactoryProtocol = WalletContactOperationFactory(
                storageFacade: SubstrateDataStorageFacade.shared,
                targetAddress: address
            )

            let transactionSubscription = TransactionSubscription(
                engine: connection,
                address: address,
                chain: chainAsset.chain,
                runtimeService: runtimeService,
                txStorage: AnyDataProviderRepository(txStorage),
                contactOperationFactory: contactOperationFactory,
                storageRequestFactory: storageRequestFactory,
                operationManager: operationManager,
                eventCenter: eventCenter,
                logger: Logger.shared
            )

            let accountInfoSubscription = AccountInfoSubscription(
                transactionSubscription: transactionSubscription,
                remoteStorageKey: accountStorageKey,
                localStorageKey: localStorageKey,
                storage: AnyDataProviderRepository(storage),
                operationManager: OperationManagerFacade.sharedManager,
                logger: Logger.shared,
                eventCenter: EventCenter.shared
            )

            subscriptionContainer = StorageSubscriptionContainer(
                engine: connection,
                children: [accountInfoSubscription],
                logger: Logger.shared
            )
        }

        let existentialDepositService = ExistentialDepositService(
            runtimeCodingService: runtimeService,
            operationManager: operationManager,
            engine: connection
        )

        let interactor = ChainAccountInteractor(
            selectedMetaAccount: selectedMetaAccount,
            chainAsset: chainAsset,
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: selectedMetaAccount
            ),
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            storageRequestFactory: storageRequestFactory,
            connection: connection,
            operationManager: operationManager,
            runtimeService: runtimeService,
            eventCenter: eventCenter,
            transactionSubscription: subscriptionContainer,
            repository: AccountRepositoryFactory.createRepository(),
            availableExportOptionsProvider: AvailableExportOptionsProvider(),
            settingsManager: SettingsManager.shared,
            existentialDepositService: existentialDepositService
        )

        let wireframe = ChainAccountWireframe()

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
        let viewModelFactory = ChainAccountViewModelFactory(assetBalanceFormatterFactory: assetBalanceFormatterFactory)

        let presenter = ChainAccountPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            logger: Logger.shared,
            selectedMetaAccount: selectedMetaAccount,
            moduleOutput: moduleOutput
        )

        interactor.presenter = presenter

        let view = ChainAccountViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return ChainAccountModule(view: view, moduleInput: presenter)
    }
}
