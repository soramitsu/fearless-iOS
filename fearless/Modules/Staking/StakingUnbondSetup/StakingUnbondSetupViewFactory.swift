import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood

final class StakingUnbondSetupViewFactory: StakingUnbondSetupViewFactoryProtocol {
    static func createView() -> StakingUnbondSetupViewProtocol? {
        guard let interactor = createInteractor(settings: SettingsManager.shared) else {
            return nil
        }

        let wireframe = StakingUnbondSetupWireframe()

        let settings = SettingsManager.shared
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let chain = settings.selectedConnection.type.chain

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

        let presenter = StakingUnbondSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            chain: chain,
            logger: Logger.shared
        )

        let view = StakingUnbondSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        settings: SettingsManagerProtocol
    ) -> StakingUnbondSetupInteractor? {
        guard let engine = WebSocketService.shared.connection else {
            return nil
        }

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

        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: RuntimeRegistryFacade.sharedService,
            engine: engine,
            operationManager: OperationManagerFacade.sharedManager
        )

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        return StakingUnbondSetupInteractor(
            assetId: assetId,
            chain: chain,
            singleValueProviderFactory: SingleValueProviderFactory.shared,
            substrateProviderFactory: substrateProviderFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            feeProxy: ExtrinsicFeeProxy(),
            accountRepository: AnyDataProviderRepository(accountRepository),
            settings: settings,
            runtimeService: RuntimeRegistryFacade.sharedService,
            operationManager: OperationManagerFacade.sharedManager
        )
    }
}
