import Foundation
import SoraKeystore
import RobinHood
import SoraFoundation

final class StakingAmountViewFactory: StakingAmountViewFactoryProtocol {
    static func createView() -> StakingAmountViewProtocol? {
        let settings = SettingsManager.shared
        let keystore = Keychain()

        guard let connection = WebSocketService.shared.connection else {
            return nil
        }

        guard let presenter = createPresenter(settings: settings,
                                              keystore: keystore) else {
            return nil
        }

        guard let interactor = createInteractor(connection: connection,
                                                settings: settings,
                                                keystore: keystore) else {
            return nil
        }

        let view = StakingAmountViewController(nib: R.nib.stakingAmountViewController)
        let wireframe = StakingAmountWireframe()

        view.uiFactory = UIFactory()
        view.localizationManager = LocalizationManager.shared

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }

    static private func createPresenter(settings: SettingsManagerProtocol,
                                        keystore: KeystoreProtocol) -> StakingAmountPresenter? {
        let networkType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(keystore: keystore, settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(networkType)

        guard let selectedAccount = settings.selectedAccount else {
            return nil
        }

        let rewardDestViewModelFactory = RewardDestinationViewModelFactory(asset: asset)
        let balanceViewModelFactory = BalanceViewModelFactory(walletPrimitiveFactory: primitiveFactory,
                                                              selectedAddressType: networkType)
        let presenter = StakingAmountPresenter(asset: asset,
                                               selectedAccount: selectedAccount,
                                               rewardDestViewModelFactory: rewardDestViewModelFactory,
                                               balanceViewModelFactory: balanceViewModelFactory,
                                               applicationConfig: ApplicationConfig.shared,
                                               logger: Logger.shared)

        return presenter
    }

    static private func createInteractor(connection: JSONRPCEngine,
                                         settings: SettingsManagerProtocol,
                                         keystore: KeystoreProtocol) -> StakingAmountInteractor? {
        let networkType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(keystore: keystore, settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(networkType)

        guard let selectedAccount = settings.selectedAccount,
              let assetId = WalletAssetId(rawValue: asset.identifier) else {
            return nil
        }

        let providerFactory = SingleValueProviderFactory.shared
        guard let balanceProvider = try? providerFactory
                .getAccountProvider(for: selectedAccount.address,
                                    runtimeService: RuntimeRegistryFacade.sharedService) else {
            return nil
        }

        let facade = UserDataStorageFacade.shared

        let filter = NSPredicate.filterAccountBy(networkType: networkType)
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            facade.createRepository(filter: filter,
                                    sortDescriptors: [.accountsByOrder])

        let extrinsicService = ExtrinsicService(address: selectedAccount.address,
                                                cryptoType: selectedAccount.cryptoType,
                                                runtimeRegistry: RuntimeRegistryFacade.sharedService,
                                                engine: connection,
                                                operationManager: OperationManagerFacade.sharedManager)

        let priceProvider = providerFactory.getPriceProvider(for: assetId)

        let interactor = StakingAmountInteractor(repository: AnyDataProviderRepository(accountRepository),
                                                 priceProvider: AnySingleValueProvider(priceProvider),
                                                 balanceProvider: AnyDataProvider(balanceProvider),
                                                 extrinsicService: extrinsicService,
                                                 rewardService: RewardCalculatorFacade.sharedService,
                                                 operationManager: OperationManagerFacade.sharedManager)

        return interactor
    }
}
