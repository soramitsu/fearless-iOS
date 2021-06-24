import Foundation
import SoraKeystore
import SoraFoundation
import RobinHood

final class StakingConfirmViewFactory: StakingConfirmViewFactoryProtocol {
    static func createInitiatedBondingView(
        for state: PreparedNomination<InitiatedBonding>
    ) -> StakingConfirmViewProtocol? {
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

        let wireframe = StakingConfirmWireframe()

        return createView(
            for: interactor,
            wireframe: wireframe,
            settings: settings
        )
    }

    static func createChangeTargetsView(
        for state: PreparedNomination<ExistingBonding>
    ) -> StakingConfirmViewProtocol? {
        let wireframe = StakingConfirmWireframe()
        return createExistingBondingView(for: state, wireframe: wireframe)
    }

    static func createChangeYourValidatorsView(
        for state: PreparedNomination<ExistingBonding>
    ) -> StakingConfirmViewProtocol? {
        let wireframe = YourValidators.StakingConfirmWireframe()
        return createExistingBondingView(for: state, wireframe: wireframe)
    }

    private static func createExistingBondingView(
        for state: PreparedNomination<ExistingBonding>,
        wireframe: StakingConfirmWireframeProtocol
    ) -> StakingConfirmViewProtocol? {
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
        for interactor: StakingBaseConfirmInteractor,
        wireframe: StakingConfirmWireframeProtocol,
        settings: SettingsManagerProtocol
    ) -> StakingConfirmViewProtocol? {
        let view = StakingConfirmViewController(nib: R.nib.stakingConfirmViewController)
        view.uiFactory = UIFactory()

        guard let presenter = createPresenter(
            view: view,
            wireframe: wireframe,
            settings: settings
        ) else {
            return nil
        }

        view.presenter = presenter
        presenter.interactor = interactor
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }

    private static func createPresenter(
        view: StakingConfirmViewProtocol,
        wireframe: StakingConfirmWireframeProtocol,
        settings: SettingsManagerProtocol
    ) -> StakingConfirmPresenter? {
        let networkType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(settings.selectedConnection.type)

        let confirmViewModelFactory = StakingConfirmViewModelFactory()

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

        let presenter = StakingConfirmPresenter(
            confirmationViewModelFactory: confirmViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            asset: asset,
            logger: Logger.shared
        )

        presenter.view = view
        presenter.wireframe = wireframe
        dataValidatingFactory.view = view

        return presenter
    }

    private static func createInitiatedBondingInteractor(
        _ nomination: PreparedNomination<InitiatedBonding>,
        connection: JSONRPCEngine,
        settings: SettingsManagerProtocol,
        keystore: KeystoreProtocol
    ) -> StakingBaseConfirmInteractor? {
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
    ) -> StakingBaseConfirmInteractor? {
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

        var controllerSettings = InMemorySettingsManager()
        controllerSettings.selectedAccount = nomination.bonding.controllerAccount
        controllerSettings.selectedConnection = networkSettings

        let signer = SigningWrapper(keystore: keystore, settings: controllerSettings)

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        return ChangeTargetsConfirmInteractor(
            singleValueProviderFactory: SingleValueProviderFactory.shared,
            extrinsicService: extrinsicService,
            runtimeService: runtimeService,
            operationManager: operationManager,
            signer: signer,
            chain: networkType.chain,
            assetId: assetId,
            repository: AnyDataProviderRepository(accountRepository),
            nomination: nomination
        )
    }
}
