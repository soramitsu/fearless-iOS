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
            let connection = chainRegistry.getConnection(for: Chain.soraMain.genesisHash),
            let runtimeService = chainRegistry.getRuntimeProvider(for: Chain.soraMain.genesisHash)
        else {
            return nil
        }
        let localizationManager = LocalizationManager.shared
        let operationManager = OperationManagerFacade.sharedManager

        let repositoryFacade = SubstrateDataStorageFacade.shared

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
            chainId: Chain.soraMain.genesisHash
        )
        let logger = Logger.shared

        let subscriptionService = PolkaswapRemoteSubscriptionService(
            connection: connection,
            logger: logger
        )

        let mapper = PolkaswapSettingMapper()
        let settingsRepository: CoreDataRepository<PolkaswapRemoteSettings, CDPolkaswapRemoteSettings> =
            repositoryFacade.createRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )

        let callFactory = SubstrateCallFactoryDefault(runtimeService: runtimeService)

        let interactor = PolkaswapAdjustmentInteractor(
            wallet: wallet,
            subscriptionService: subscriptionService,
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            feeProxy: ExtrinsicFeeProxy(),
            settingsRepository: AnyDataProviderRepository(settingsRepository),
            operationFactory: operationFactory,
            operationManager: operationManager,
            userDefaultsStorage: SettingsManager.shared,
            callFactory: callFactory,
            chainModelRepo: ServiceAssembly.shared.asyncChainModelRepository()
        )
        let router = PolkaswapAdjustmentRouter()

        let viewModelFactory = PolkaswapAdjustmentViewModelFactory(
            wallet: wallet,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )

        let dataValidatingFactory = SendDataValidatingFactory(presentable: router)
        let presenter = PolkaswapAdjustmentPresenter(
            wallet: wallet,
            swapChainAsset: chainAsset,
            viewModelFactory: viewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            interactor: interactor,
            router: router,
            swapVariant: swapVariant,
            localizationManager: localizationManager
        )

        guard
            let bannersModule = Self.configureBannersModule(output: presenter, wallet: wallet)
        else {
            return nil
        }

        let view = PolkaswapAdjustmentViewController(
            output: presenter,
            bannersViewController: bannersModule.view.controller,
            localizationManager: localizationManager
        )
        dataValidatingFactory.view = view
        presenter.bannersModuleInput = bannersModule.input

        return (view, presenter)
    }

    // MARK: - Cofigure Modules

    private static func configureBannersModule(
        output: BannersModuleOutput?,
        wallet: MetaAccountModel
    ) -> BannersModuleCreationResult? {
        BannersAssembly.configureModule(output: output, type: .embed, wallet: wallet)
    }
}
