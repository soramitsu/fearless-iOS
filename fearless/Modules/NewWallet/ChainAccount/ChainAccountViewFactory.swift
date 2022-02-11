import Foundation
import SoraFoundation
import FearlessUtils

struct ChainAccountModule {
    let view: ChainAccountViewProtocol?
    let moduleInput: ChainAccountModuleInput?
}

enum ChainAccountViewFactory {
    static func createView(
        chain: ChainModel,
        asset: AssetModel,
        selectedMetaAccount: MetaAccountModel,
        moduleOutput: ChainAccountModuleOutput?
    ) -> ChainAccountModule? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
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

        let interactor = ChainAccountInteractor(
            selectedMetaAccount: selectedMetaAccount,
            chain: chain,
            asset: asset,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            storageRequestFactory: storageRequestFactory,
            connection: connection,
            operationManager: operationManager,
            runtimeService: runtimeService,
            eventCenter: EventCenter.shared
        )
        let wireframe = ChainAccountWireframe()

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
        let viewModelFactory = ChainAccountViewModelFactory(assetBalanceFormatterFactory: assetBalanceFormatterFactory)

        let presenter = ChainAccountPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            logger: Logger.shared,
            asset: asset,
            chain: chain,
            selectedMetaAccount: selectedMetaAccount,
            moduleOutput: moduleOutput
        )

        let view = ChainAccountViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return ChainAccountModule(view: view, moduleInput: presenter)
    }
}
