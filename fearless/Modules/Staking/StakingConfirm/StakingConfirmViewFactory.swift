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

        return createView(for: interactor, settings: settings, keystore: keystore)
    }

    static func createChangeTargetsView(
        for state: PreparedNomination<ExistingBonding>
    ) -> StakingConfirmViewProtocol? {
        let settings = SettingsManager.shared
        let keystore = Keychain()

        guard let connection = WebSocketService.shared.connection else {
            return nil
        }

        let primitiveFactory = WalletPrimitiveFactory(keystore: keystore, settings: settings)
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

        return createView(for: interactor, settings: settings, keystore: keystore)
    }

    private static func createView(
        for interactor: StakingBaseConfirmInteractor,
        settings: SettingsManagerProtocol,
        keystore: KeystoreProtocol
    ) -> StakingConfirmViewProtocol? {
        guard let presenter = createPresenter(
            settings: settings,
            keystore: keystore
        ) else {
            return nil
        }

        let view = StakingConfirmViewController(nib: R.nib.stakingConfirmViewController)
        view.uiFactory = UIFactory()

        let wireframe = StakingConfirmWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }

    private static func createPresenter(
        settings: SettingsManagerProtocol,
        keystore: KeystoreProtocol
    ) -> StakingConfirmPresenter? {
        let networkType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(keystore: keystore, settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(settings.selectedConnection.type)

        let confirmViewModelFactory = StakingConfirmViewModelFactory()

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: networkType,
            limit: StakingConstants.maxAmount
        )

        return StakingConfirmPresenter(
            confirmationViewModelFactory: confirmViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            asset: asset
        )
    }

    private static func createInitiatedBondingInteractor(
        _ nomination: PreparedNomination<InitiatedBonding>,
        connection: JSONRPCEngine,
        settings: SettingsManagerProtocol,
        keystore: KeystoreProtocol
    ) -> StakingBaseConfirmInteractor? {
        let primitiveFactory = WalletPrimitiveFactory(keystore: keystore, settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(settings.selectedConnection.type)

        guard let selectedAccount = settings.selectedAccount,
              let assetId = WalletAssetId(rawValue: asset.identifier)
        else {
            return nil
        }

        let providerFactory = SingleValueProviderFactory.shared
        guard let balanceProvider = try? providerFactory
            .getAccountProvider(
                for: selectedAccount.address,
                runtimeService: RuntimeRegistryFacade.sharedService
            )
        else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

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

        let priceProvider = providerFactory.getPriceProvider(for: assetId)

        return InitiatedBondingConfirmInteractor(
            priceProvider: AnySingleValueProvider(priceProvider),
            balanceProvider: AnyDataProvider(balanceProvider),
            extrinsicService: extrinsicService,
            operationManager: operationManager,
            signer: signer,
            settings: settings,
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
        let providerFactory = SingleValueProviderFactory.shared
        guard let balanceProvider = try? providerFactory
            .getAccountProvider(
                for: nomination.bonding.controllerAccount.address,
                runtimeService: RuntimeRegistryFacade.sharedService
            )
        else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let extrinsicSender = nomination.bonding.controllerAccount

        let extrinsicService = ExtrinsicService(
            address: extrinsicSender.address,
            cryptoType: extrinsicSender.cryptoType,
            runtimeRegistry: RuntimeRegistryFacade.sharedService,
            engine: connection,
            operationManager: operationManager
        )

        var controllerSettings = InMemorySettingsManager()
        controllerSettings.selectedAccount = nomination.bonding.controllerAccount
        controllerSettings.selectedConnection = networkSettings

        let signer = SigningWrapper(keystore: keystore, settings: controllerSettings)

        let priceProvider = providerFactory.getPriceProvider(for: assetId)

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        return ChangeTargetsConfirmInteractor(
            priceProvider: priceProvider,
            balanceProvider: balanceProvider,
            extrinsicService: extrinsicService,
            operationManager: operationManager,
            signer: signer,
            repository: AnyDataProviderRepository(accountRepository),
            nomination: nomination
        )
    }
}
