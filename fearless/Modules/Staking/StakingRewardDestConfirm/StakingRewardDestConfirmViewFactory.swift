import Foundation
import SoraKeystore
import RobinHood
import SoraFoundation

struct StakingRewardDestConfirmViewFactory {
    static func createView(
        for rewardDestination: RewardDestination<AccountItem>
    ) -> StakingRewardDestConfirmViewProtocol? {
        let settings = SettingsManager.shared

        guard let interactor = createInteractor(settings: SettingsManager.shared) else {
            return nil
        }

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)

        let chain = settings.selectedConnection.type.chain

        let wireframe = StakingRewardDestConfirmWireframe()

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

        let presenter = StakingRewardDestConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            rewardDestination: rewardDestination,
            confirmModelFactory: StakingRewardDestConfirmVMFactory(),
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            chain: chain,
            logger: Logger.shared
        )

        let view = StakingRewardDestConfirmViewController(
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
    ) -> StakingRewardDestConfirmInteractor? {
        guard
            let engine = WebSocketService.shared.connection else {
            return nil
        }

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
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> = UserDataStorageFacade.shared
            .createRepository(
                filter: filter, sortDescriptors: [.accountsByOrder]
            )

        return StakingRewardDestConfirmInteractor(
            settings: settings,
            singleValueProviderFactory: SingleValueProviderFactory.shared,
            extrinsicServiceFactory: extrinsicServiceFactory,
            substrateProviderFactory: substrateProviderFactory,
            runtimeService: RuntimeRegistryFacade.sharedService,
            operationManager: OperationManagerFacade.sharedManager,
            accountRepository: AnyDataProviderRepository(accountRepository),
            feeProxy: ExtrinsicFeeProxy(),
            assetId: assetId,
            chain: chain
        )
    }
}
