import UIKit
import SoraFoundation
import SSFUtils
import RobinHood
import SoraKeystore

final class PolkaswapAdjustmentAssembly {
    static func configureModule(
        swapChainAsset: ChainAsset,
        swapVariant: SwapVariant = .desiredInput,
        wallet: MetaAccountModel
    ) -> PolkaswapAdjustmentModuleCreationResult? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        guard let connection = chainRegistry.getConnection(for: swapChainAsset.chain.chainId),
              let accountResponse = wallet.fetch(for: swapChainAsset.chain.accountRequest()),
              let runtimeService = chainRegistry.getRuntimeProvider(for: swapChainAsset.chain.chainId),
              let xorChainAsset = swapChainAsset.chain.utilityChainAssets().first
        else {
            return nil
        }
        let localizationManager = LocalizationManager.shared
        let operationManager = OperationManagerFacade.sharedManager

        let repositoryFacade = SubstrateDataStorageFacade.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: repositoryFacade
        )

        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedMetaAccount: wallet
        )

        let storageOperationFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let operationFactory = PolkaswapOperationFactory(
            engine: connection,
            storageRequestFactory: storageOperationFactory,
            runtimeService: runtimeService
        )
        let logger = Logger.shared

        let subscriptionService = PolkaswapRemoteSubscriptionService(
            connection: connection,
            logger: logger
        )

        let extrinsicService = ExtrinsicService(
            accountId: accountResponse.accountId,
            chainFormat: swapChainAsset.chain.chainFormat,
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
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
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
            soraChainAsset: xorChainAsset,
            swapChainAsset: swapChainAsset,
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
