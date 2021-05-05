import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood

struct StakingBondMoreConfirmViewFactory {
    static func createView(from amount: Decimal) -> StakingBondMoreConfirmationViewProtocol? {
        guard let interactor = createInteractor() else {
            return nil
        }

        let wireframe = StakingBondMoreConfirmationWireframe()

        let presenter = createPresenter(from: interactor, wireframe: wireframe, amount: amount)

        let view = StakingBondMoreConfirmationVC(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createPresenter(
        from interactor: StakingBondMoreConfirmationInteractorInputProtocol,
        wireframe: StakingBondMoreConfirmationWireframeProtocol,
        amount: Decimal
    ) -> StakingBondMoreConfirmationPresenter {
        let settings = SettingsManager.shared

        let chain = settings.selectedConnection.type.chain
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(chain.addressType)

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

        let confirmationViewModelFactory = StakingBondMoreConfirmViewModelFactory(asset: asset)

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        return StakingBondMoreConfirmationPresenter(
            interactor: interactor,
            wireframe: wireframe,
            inputAmount: amount,
            confirmViewModelFactory: confirmationViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            chain: chain,
            logger: Logger.shared
        )
    }

    private static func createInteractor() -> StakingBondMoreConfirmationInteractor? {
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

        return StakingBondMoreConfirmationInteractor(
            settings: settings,
            singleValueProviderFactory: SingleValueProviderFactory.shared,
            substrateProviderFactory: substrateProviderFactory,
            accountRepository: AnyDataProviderRepository(accountRepository),
            extrinsicServiceFactory: extrinsicServiceFactory,
            feeProxy: ExtrinsicFeeProxy(),
            runtimeService: RuntimeRegistryFacade.sharedService,
            operationManager: OperationManagerFacade.sharedManager,
            chain: chain,
            assetId: assetId
        )
    }
}
