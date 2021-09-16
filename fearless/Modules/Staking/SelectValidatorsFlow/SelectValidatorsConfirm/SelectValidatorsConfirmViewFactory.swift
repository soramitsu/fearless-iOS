import Foundation
import SoraKeystore
import SoraFoundation
import RobinHood
import FearlessUtils

final class SelectValidatorsConfirmViewFactory: SelectValidatorsConfirmViewFactoryProtocol {
    static func createInitiatedBondingView(
        for state: PreparedNomination<InitiatedBonding>
    ) -> SelectValidatorsConfirmViewProtocol? {
        let settings = SettingsManager.shared
        let keystore = Keychain()

        guard let connection = WebSocketService.shared.connection else {
            return nil
        }

        guard let interactor = createInitiatedBondingInteractor(
            state,
            connection: connection,
            settings: settings,
            keystore: keystore
        ) else {
            return nil
        }

        let wireframe = SelectValidatorsConfirmWireframe()

        return createView(
            for: interactor,
            wireframe: wireframe,
            settings: settings
        )
    }

    static func createChangeTargetsView(
        for state: PreparedNomination<ExistingBonding>
    ) -> SelectValidatorsConfirmViewProtocol? {
        let wireframe = SelectValidatorsConfirmWireframe()
        return createExistingBondingView(for: state, wireframe: wireframe)
    }

    static func createChangeYourValidatorsView(
        for state: PreparedNomination<ExistingBonding>
    ) -> SelectValidatorsConfirmViewProtocol? {
        let wireframe = YourValidatorList.SelectValidatorsConfirmWireframe()
        return createExistingBondingView(for: state, wireframe: wireframe)
    }

    private static func createExistingBondingView(
        for state: PreparedNomination<ExistingBonding>,
        wireframe: SelectValidatorsConfirmWireframeProtocol
    ) -> SelectValidatorsConfirmViewProtocol? {
        let settings = SettingsManager.shared
        let keystore = Keychain()

        guard let connection = WebSocketService.shared.connection else {
            return nil
        }

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(settings.selectedConnection.type)

        guard let assetId = WalletAssetId(rawValue: asset.identifier) else {
            return nil
        }

        let networkSettnigs = settings.selectedConnection

        guard let interactor = createChangeTargetsInteractor(
            state,
            connection: connection,
            keystore: keystore,
            assetId: assetId,
            networkSettings: networkSettnigs
        ) else {
            return nil
        }

        return createView(
            for: interactor,
            wireframe: wireframe,
            settings: settings
        )
    }

    private static func createView(
        for interactor: SelectValidatorsConfirmInteractorBase,
        wireframe: SelectValidatorsConfirmWireframeProtocol,
        settings: SettingsManagerProtocol
    ) -> SelectValidatorsConfirmViewProtocol? {
        let networkType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(settings.selectedConnection.type)

        let confirmViewModelFactory = SelectValidatorsConfirmViewModelFactory()

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: networkType,
            limit: StakingConstants.maxAmount
        )

        let errorBalanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: networkType,
            limit: StakingConstants.maxAmount,
            formatterFactory: AmountFormatterFactory(assetPrecision: Int(networkType.precision))
        )

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: errorBalanceViewModelFactory
        )

        let presenter = SelectValidatorsConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            confirmationViewModelFactory: confirmViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            asset: asset,
            logger: Logger.shared
        )

        let view = SelectValidatorsConfirmViewController(
            presenter: presenter,
            quantityFormatter: .quantity,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInitiatedBondingInteractor(
        _ nomination: PreparedNomination<InitiatedBonding>,
        connection: JSONRPCEngine,
        settings: SettingsManagerProtocol,
        keystore: KeystoreProtocol
    ) -> SelectValidatorsConfirmInteractorBase? {
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(settings.selectedConnection.type)

        guard let selectedAccount = settings.selectedAccount,
              let assetId = WalletAssetId(rawValue: asset.identifier)
        else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let runtimeService = RuntimeRegistryFacade.sharedService

        let extrinsicService = ExtrinsicService(
            address: selectedAccount.address,
            cryptoType: selectedAccount.cryptoType,
            runtimeRegistry: RuntimeRegistryFacade.sharedService,
            engine: connection,
            operationManager: operationManager
        )

        let signer = SigningWrapper(
            keystore: keystore,
            settings: settings
        )

        return InitiatedBondingConfirmInteractor(
            selectedAccount: selectedAccount,
            selectedConnection: settings.selectedConnection,
            singleValueProviderFactory: SingleValueProviderFactory.shared,
            extrinsicService: extrinsicService,
            runtimeService: runtimeService,
            durationOperationFactory: StakingDurationOperationFactory(),
            operationManager: operationManager,
            signer: signer,
            assetId: assetId,
            nomination: nomination
        )
    }

    private static func createChangeTargetsInteractor(
        _ nomination: PreparedNomination<ExistingBonding>,
        connection: JSONRPCEngine,
        keystore: KeystoreProtocol,
        assetId: WalletAssetId,
        networkSettings: ConnectionItem
    ) -> SelectValidatorsConfirmInteractorBase? {
        let settings = SettingsManager.shared
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let networkType = settings.selectedConnection.type
        let asset = primitiveFactory.createAssetForAddressType(networkType)

        guard let assetId = WalletAssetId(rawValue: asset.identifier) else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let extrinsicSender = nomination.bonding.controllerAccount

        let runtimeService = RuntimeRegistryFacade.sharedService

        let extrinsicService = ExtrinsicService(
            address: extrinsicSender.address,
            cryptoType: extrinsicSender.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let controllerSettings = InMemorySettingsManager()
        controllerSettings.selectedAccount = nomination.bonding.controllerAccount
        controllerSettings.selectedConnection = networkSettings

        let signer = SigningWrapper(keystore: keystore, settings: controllerSettings)

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        return ChangeTargetsConfirmInteractor(
            singleValueProviderFactory: SingleValueProviderFactory.shared,
            extrinsicService: extrinsicService,
            runtimeService: runtimeService,
            durationOperationFactory: StakingDurationOperationFactory(),
            operationManager: operationManager,
            signer: signer,
            chain: networkType.chain,
            assetId: assetId,
            repository: AnyDataProviderRepository(accountRepository),
            nomination: nomination
        )
    }
}
