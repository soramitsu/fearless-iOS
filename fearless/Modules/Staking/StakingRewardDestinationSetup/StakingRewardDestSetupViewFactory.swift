import SoraFoundation
import SoraKeystore
import RobinHood

final class StakingRewardDestSetupViewFactory: StakingRewardDestSetupViewFactoryProtocol {
    static func createView() -> StakingRewardDestSetupViewProtocol? {
        let settings = SettingsManager.shared
        let networkType = settings.selectedConnection.type
        let chain = settings.selectedConnection.type.chain
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(networkType)

        guard let interactor = createInteractor(settings: settings) else {
            return nil
        }

        let wireframe = StakingRewardDestSetupWireframe()

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

        let presenter = StakingRewardDestSetupPresenter(
            wireframe: wireframe,
            interactor: interactor,
            rewardDestViewModelFactory: RewardDestinationViewModelFactory(asset: asset),
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            applicationConfig: ApplicationConfig.shared,
            chain: chain,
            logger: Logger.shared
        )

        let view = StakingRewardDestSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        settings: SettingsManagerProtocol
    ) -> StakingRewardDestSetupInteractor? {
        guard let engine = WebSocketService.shared.connection else { return nil }

        let chain = settings.selectedConnection.type.chain

        let networkType = chain.addressType

        let asset = WalletPrimitiveFactory(settings: settings)
            .createAssetForAddressType(networkType)

        guard let assetId = WalletAssetId(rawValue: asset.identifier) else {
            return nil
        }

        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: RuntimeRegistryFacade.sharedService,
            engine: engine,
            operationManager: OperationManagerFacade.sharedManager
        )

        let substrateProviderFactory = SubstrateDataProviderFactory(
            facade: SubstrateDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        let filter = NSPredicate.filterAccountBy(networkType: networkType)
        let accountRepository:
            CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository(
                filter: filter, sortDescriptors: [.accountsByOrder]
            )

        return StakingRewardDestSetupInteractor(
            settings: settings,
            singleValueProviderFactory: SingleValueProviderFactory.shared,
            extrinsicServiceFactory: extrinsicServiceFactory,
            substrateProviderFactory: substrateProviderFactory,
            calculatorService: RewardCalculatorFacade.sharedService,
            runtimeService: RuntimeRegistryFacade.sharedService,
            operationManager: OperationManagerFacade.sharedManager,
            accountRepository: AnyDataProviderRepository(accountRepository),
            feeProxy: ExtrinsicFeeProxy(),
            assetId: assetId,
            chain: chain
        )
    }
}
