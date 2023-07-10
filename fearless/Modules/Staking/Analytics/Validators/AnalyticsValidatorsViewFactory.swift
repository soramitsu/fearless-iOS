import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood
import SSFUtils
import SSFModels

struct AnalyticsValidatorsViewFactory {
    static func createView(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) -> AnalyticsValidatorsViewProtocol? {
        guard let interactor = createInteractor(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount
        ) else {
            return nil
        }
        let wireframe = AnalyticsValidatorsWireframe()
        let presenter = createPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount
        )
        let view = AnalyticsValidatorsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) -> AnalyticsValidatorsInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let chainAsset = ChainAsset(chain: chain, asset: asset)

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let logger = Logger.shared

        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: substrateStorageFacade,
            operationManager: operationManager,
            logger: Logger.shared
        )

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let identityOperationFactory = IdentityOperationFactory(requestFactory: requestFactory)
        let substrateProviderFactory = SubstrateDataProviderFactory(
            facade: SubstrateDataStorageFacade.shared,
            operationManager: operationManager,
            logger: logger
        )

        return AnalyticsValidatorsInteractor(
            substrateProviderFactory: substrateProviderFactory,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            identityOperationFactory: identityOperationFactory,
            operationManager: operationManager,
            engine: connection,
            runtimeService: runtimeService,
            storageRequestFactory: requestFactory,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount
        )
    }

    private static func createPresenter(
        interactor: AnalyticsValidatorsInteractor,
        wireframe: AnalyticsValidatorsWireframe,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) -> AnalyticsValidatorsPresenter {
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,

            selectedMetaAccount: selectedAccount
        )
        let viewModelFactory = AnalyticsValidatorsViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            chain: chain,
            asset: asset,
            iconGenerator: UniversalIconGenerator(chain: chain)
        )

        let presenter = AnalyticsValidatorsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared,
            asset: asset,
            chain: chain,
            selectedAccount: selectedAccount
        )
        return presenter
    }
}
