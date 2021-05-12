import Foundation
import SoraFoundation
import FearlessUtils
import SoraKeystore
import RobinHood

struct ControllerAccountConfirmationViewFactory {
    static func createView(
        controllerAccountItem: AccountItem
    ) -> ControllerAccountConfirmationViewProtocol? {
        let settings = SettingsManager.shared

        guard let engine = WebSocketService.shared.connection else {
            return nil
        }

        let chain = settings.selectedConnection.type.chain
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)

        guard let interactor = createInteractor(
            controllerAccountItem: controllerAccountItem,
            primitiveFactory: primitiveFactory,
            connection: engine,
            chain: chain,
            settings: settings
        ) else {
            return nil
        }

        let wireframe = ControllerAccountConfirmationWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)
        let presenter = ControllerAccountConfirmationPresenter(
            controllerAccountItem: controllerAccountItem,
            chain: chain,
            iconGenerator: PolkadotIconGenerator(),
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory
        )

        let view = ControllerAccountConfirmationVC(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        controllerAccountItem: AccountItem,
        primitiveFactory: WalletPrimitiveFactoryProtocol,
        connection: JSONRPCEngine,
        chain: Chain,
        settings: SettingsManagerProtocol
    ) -> ControllerAccountConfirmationInteractor? {
        let operationManager = OperationManagerFacade.sharedManager
        let runtimeService = RuntimeRegistryFacade.sharedService
        let substrateProviderFactory = SubstrateDataProviderFactory(
            facade: SubstrateDataStorageFacade.shared,
            operationManager: operationManager
        )

        let asset = primitiveFactory.createAssetForAddressType(chain.addressType)

        guard
            let assetId = WalletAssetId(rawValue: asset.identifier),
            let selectedAccount = settings.selectedAccount
        else {
            return nil
        }

        let facade = UserDataStorageFacade.shared

        let filter = NSPredicate.filterAccountBy(networkType: chain.addressType)
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            facade.createRepository(
                filter: filter,
                sortDescriptors: [.accountsByOrder]
            )

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let interactor = ControllerAccountConfirmationInteractor(
            singleValueProviderFactory: SingleValueProviderFactory.shared,
            substrateProviderFactory: substrateProviderFactory,
            runtimeService: runtimeService,
            extrinsicServiceFactory: extrinsicServiceFactory,
            signingWrapper: SigningWrapper(keystore: Keychain(), settings: settings),
            feeProxy: ExtrinsicFeeProxy(),
            assetId: assetId,
            controllerAccountItem: controllerAccountItem,
            accountRepository: AnyDataProviderRepository(accountRepository),
            operationManager: operationManager,
            storageRequestFactory: storageRequestFactory,
            selectedAccountAddress: selectedAccount.address,
            engine: connection,
            chain: chain
        )
        return interactor
    }
}
