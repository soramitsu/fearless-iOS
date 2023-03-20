import UIKit
import SoraFoundation
import FearlessUtils
import RobinHood
import SoraKeystore

final class PolkaswapAdjustmentAssembly {
    static func configureModule(
        swapFromChainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) -> PolkaswapAdjustmentModuleCreationResult? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        guard let connection = chainRegistry.getConnection(for: swapFromChainAsset.chain.chainId),
              let accountResponse = wallet.fetch(for: swapFromChainAsset.chain.accountRequest()),
              let runtimeService = chainRegistry.getRuntimeProvider(for: swapFromChainAsset.chain.chainId),
              let xorChainAsset = swapFromChainAsset.chain.utilityChainAssets().first
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
            chainFormat: swapFromChainAsset.chain.chainFormat,
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

        let callFactory = SubstrateCallFactory(runtimeSpecVersion: runtimeService.runtimeSpecVersion)

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
            swapFromChainAsset: swapFromChainAsset,
            viewModelFactory: viewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            interactor: interactor,
            router: router,
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
