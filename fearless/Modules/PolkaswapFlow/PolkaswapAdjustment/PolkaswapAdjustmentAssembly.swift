import UIKit
import SoraFoundation
import SSFUtils
import RobinHood
import SoraKeystore
import SSFModels

final class PolkaswapAdjustmentAssembly {
    static func configureModule(
        chainAsset: ChainAsset?,
        swapVariant: SwapVariant = .desiredInput,
        wallet: MetaAccountModel
    ) -> PolkaswapAdjustmentModuleCreationResult? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let xorChainAsset = chainRegistry.getChain(for: Chain.soraMain.genesisHash)?.utilityChainAssets().first,
            let connection = chainRegistry.getConnection(for: xorChainAsset.chain.chainId),
            let accountResponse = wallet.fetch(for: xorChainAsset.chain.accountRequest()),
            let runtimeService = chainRegistry.getRuntimeProvider(for: xorChainAsset.chain.chainId)
        else {
            return nil
        }
        let localizationManager = LocalizationManager.shared
        let operationManager = OperationManagerFacade.sharedManager

        let repositoryFacade = SubstrateDataStorageFacade.shared
        let priceLocalSubscriber = PriceLocalStorageSubscriberImpl.shared

        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedMetaAccount: wallet
        )

        let storageOperationFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let operationFactory = PolkaswapOperationFactory(
            storageRequestFactory: storageOperationFactory,
            chainRegistry: chainRegistry,
            chainId: xorChainAsset.chain.chainId
        )
        let logger = Logger.shared

        let subscriptionService = PolkaswapRemoteSubscriptionService(
            connection: connection,
            logger: logger
        )

        let extrinsicService = ExtrinsicService(
            accountId: accountResponse.accountId,
            chainFormat: xorChainAsset.chain.chainFormat,
            cryptoType: accountResponse.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let mapper = PolkaswapSettingMapper()
        let settingsRepository: CoreDataRepository<PolkaswapRemoteSettings, CDPolkaswapRemoteSettings> =
            repositoryFacade.createRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )

        let callFactory = SubstrateCallFactoryAssembly.createCallFactory(for: runtimeService.runtimeSpecVersion)

        let interactor = PolkaswapAdjustmentInteractor(
            xorChainAsset: xorChainAsset,
            subscriptionService: subscriptionService,
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            priceLocalSubscriber: priceLocalSubscriber,
            feeProxy: ExtrinsicFeeProxy(),
            settingsRepository: AnyDataProviderRepository(settingsRepository),
            extrinsicService: extrinsicService,
            operationFactory: operationFactory,
            operationManager: operationManager,
            userDefaultsStorage: SettingsManager.shared,
            callFactory: callFactory
        )
        let router = PolkaswapAdjustmentRouter()

        let viewModelFactory = PolkaswapAdjustmentViewModelFactory(
            wallet: wallet,
            xorChainAsset: xorChainAsset,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )

        let dataValidatingFactory = SendDataValidatingFactory(presentable: router)
        let presenter = PolkaswapAdjustmentPresenter(
            wallet: wallet,
            xorChainAsset: xorChainAsset,
            swapChainAsset: chainAsset,
            viewModelFactory: viewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            interactor: interactor,
            router: router,
            swapVariant: swapVariant,
            localizationManager: localizationManager
        )

        let view = PolkaswapAdjustmentViewController(
            output: presenter,
            localizationManager: localizationManager
        )
        dataValidatingFactory.view = view

        return (view, presenter)
    }
}
