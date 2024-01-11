import Foundation
import SoraFoundation
import SSFUtils
import RobinHood
import SoraKeystore
import SSFModels

struct ChainAccountModule {
    let view: ChainAccountViewProtocol?
    let moduleInput: ChainAccountModuleInput?
}

// swiftlint:disable function_body_length
enum ChainAccountViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        moduleOutput: ChainAccountModuleOutput,
        mode: ChainAccountViewMode
    ) -> ChainAccountModule? {
        let operationManager = OperationManagerFacade.sharedManager
        let eventCenter = EventCenter.shared
        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )

        let accountInfoRepository = substrateRepositoryFactory.createAccountInfoStorageItemRepository()
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .background
        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: operationQueue
        )

        let keyFactory = StorageKeyFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let walletBalanceSubscriptionAdapter = WalletBalanceSubscriptionAdapter.shared

        let ethereumBalanceRepositoryCacheWrapper = EthereumBalanceRepositoryCacheWrapper(
            logger: Logger.shared,
            repository: accountInfoRepository,
            operationManager: OperationManagerFacade.sharedManager
        )
        let ethereumRemoteBalanceFetching = EthereumRemoteBalanceFetching(
            chainRegistry: chainRegistry,
            repositoryWrapper: ethereumBalanceRepositoryCacheWrapper
        )
        let interactor = ChainAccountInteractor(
            wallet: wallet,
            chainAsset: chainAsset,
            operationManager: operationManager,
            eventCenter: eventCenter,
            repository: AccountRepositoryFactory.createRepository(),
            availableExportOptionsProvider: AvailableExportOptionsProvider(),
            chainAssetFetching: chainAssetFetching,
            storageRequestFactory: storageRequestFactory,
            walletBalanceSubscriptionAdapter: walletBalanceSubscriptionAdapter,
            ethRemoteBalanceFetching: ethereumRemoteBalanceFetching
        )

        let wireframe = ChainAccountWireframe()

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
        let viewModelFactory = ChainAccountViewModelFactory(assetBalanceFormatterFactory: assetBalanceFormatterFactory)
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: chainAsset.assetDisplayInfo, selectedMetaAccount: wallet)
        guard let balanceInfoModule = Self.configureBalanceInfoModule(
            wallet: wallet,
            chainAsset: chainAsset
        )
        else {
            return nil
        }

        let presenter = ChainAccountPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            logger: Logger.shared,
            wallet: wallet,
            moduleOutput: moduleOutput,
            balanceInfoModule: balanceInfoModule.input,
            localizationManager: LocalizationManager.shared,
            balanceViewModelFactory: balanceViewModelFactory,
            mode: mode
        )

        interactor.presenter = presenter

        let view = ChainAccountViewController(
            presenter: presenter,
            balanceInfoViewController: balanceInfoModule.view.controller,
            localizationManager: LocalizationManager.shared,
            mode: mode
        )

        presenter.view = view

        return ChainAccountModule(view: view, moduleInput: presenter)
    }

    private static func configureBalanceInfoModule(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) -> BalanceInfoModuleCreationResult? {
        BalanceInfoAssembly.configureModule(with: .chainAsset(
            wallet: wallet,
            chainAsset: chainAsset
        ))
    }
}
