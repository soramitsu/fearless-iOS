import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood
import FearlessUtils

struct StakingRebondConfirmationViewFactory {
    static func createView(for variant: SelectedRebondVariant)
        -> StakingRebondConfirmationViewProtocol? {
        guard let interactor = createInteractor() else {
            return nil
        }

        let wireframe = StakingRebondConfirmationWireframe()

        let presenter = createPresenter(for: variant, interactor: interactor, wireframe: wireframe)

        let view = StakingRebondConfirmationViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createPresenter(
        for variant: SelectedRebondVariant,
        interactor: StakingRebondConfirmationInteractorInputProtocol,
        wireframe: StakingRebondConfirmationWireframeProtocol
    ) -> StakingRebondConfirmationPresenter {
        let settings = SettingsManager.shared

        let chain = settings.selectedConnection.type.chain
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(chain.addressType)

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

        let confirmationViewModelFactory = StakingRebondConfirmationViewModelFactory(asset: asset)

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        return StakingRebondConfirmationPresenter(
            variant: variant,
            interactor: interactor,
            wireframe: wireframe,
            confirmViewModelFactory: confirmationViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            chain: chain,
            logger: Logger.shared
        )
    }

    private static func createInteractor() -> StakingRebondConfirmationInteractor? {
        let settings = SettingsManager.shared

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

        return StakingRebondConfirmationInteractor(
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
