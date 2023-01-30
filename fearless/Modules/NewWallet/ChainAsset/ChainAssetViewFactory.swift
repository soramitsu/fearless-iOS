import Foundation
import SoraFoundation
import FearlessUtils
import RobinHood
import SoraKeystore

struct ChainAccountModule {
    let view: ChainAssetViewProtocol?
    let moduleInput: ChainAssetModuleInput?
}

// swiftlint:disable function_body_length
enum ChainAssetViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        moduleOutput: ChainAssetModuleOutput
    ) -> ChainAccountModule? {
        let operationManager = OperationManagerFacade.sharedManager
        let eventCenter = EventCenter.shared
        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let accountInfoRepository = substrateRepositoryFactory.createChainStorageItemRepository()

        let accountInfoFetching = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .background
        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            accountInfoFetching: accountInfoFetching,
            operationQueue: operationQueue,
            meta: wallet
        )

        let interactor = ChainAssetInteractor(
            wallet: wallet,
            chainAsset: chainAsset,
            operationManager: operationManager,
            eventCenter: eventCenter,
            repository: AccountRepositoryFactory.createRepository(),
            availableExportOptionsProvider: AvailableExportOptionsProvider(),
            chainAssetFetching: chainAssetFetching
        )

        let wireframe = ChainAssetWireframe()

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
        let viewModelFactory = ChainAccountViewModelFactory(assetBalanceFormatterFactory: assetBalanceFormatterFactory)

        guard let balanceInfoModule = Self.configureBalanceInfoModule(
            wallet: wallet,
            chainAsset: chainAsset
        )
        else {
            return nil
        }

        let presenter = ChainAssetPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            logger: Logger.shared,
            wallet: wallet,
            moduleOutput: moduleOutput,
            balanceInfoModule: balanceInfoModule.input,
            localizationManager: LocalizationManager.shared
        )

        interactor.presenter = presenter

        let view = ChainAssetViewController(
            presenter: presenter,
            balanceInfoViewController: balanceInfoModule.view.controller,
            localizationManager: LocalizationManager.shared
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
