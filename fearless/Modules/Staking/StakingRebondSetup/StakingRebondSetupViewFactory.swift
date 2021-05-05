import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood

final class StakingRebondSetupViewFactory: StakingRebondSetupViewFactoryProtocol {
    static func createView() -> StakingRebondSetupViewProtocol? {
        // MARK: - Interactor

        guard let interactor = createInteractor(settings: SettingsManager.shared) else {
            return nil
        }

        // MARK: - Router

        let wireframe = StakingRebondSetupWireframe()

        // MARK: - Presenter

        let settings = SettingsManager.shared
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let chain = settings.selectedConnection.type.chain

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingRebondSetupPresenter(
            wireframe: wireframe,
            interactor: interactor,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            chain: chain
        )

        // MARK: - View

        let view = StakingRebondSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
        view.localizationManager = LocalizationManager.shared

        presenter.view = view
        dataValidatingFactory.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        settings: SettingsManagerProtocol
    ) -> StakingRebondSetupInteractor? {
//        guard let engine = WebSocketService.shared.connection else {
//            return nil
//        }

        let substrateProviderFactory = SubstrateDataProviderFactory(
            facade: SubstrateDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        let chain = settings.selectedConnection.type.chain
        let networkType = chain.addressType

        let asset = WalletPrimitiveFactory(settings: settings)
            .createAssetForAddressType(networkType)

        guard let assetId = WalletAssetId(rawValue: asset.identifier) else {
            return nil
        }
//
//        let extrinsicServiceFactory = ExtrinsicServiceFactory(
//            runtimeRegistry: RuntimeRegistryFacade.sharedService,
//            engine: engine,
//            operationManager: OperationManagerFacade.sharedManager
//        )

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        return StakingRebondSetupInteractor(
            settings: settings,
            substrateProviderFactory: substrateProviderFactory,
            singleValueProviderFactory: SingleValueProviderFactory.shared,
            runtimeCodingService: RuntimeRegistryFacade.sharedService,
            operationManager: OperationManagerFacade.sharedManager,
            accountRepository: AnyDataProviderRepository(accountRepository),
            feeProxy: ExtrinsicFeeProxy(),
            chain: chain,
            assetId: assetId
        )
    }
}
