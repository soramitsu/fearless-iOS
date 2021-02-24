import Foundation
import SoraKeystore
import RobinHood
import SoraFoundation

final class StakingAmountViewFactory: StakingAmountViewFactoryProtocol {
    static func createView() -> StakingAmountViewProtocol? {
        let settings = SettingsManager.shared
        let keystore = Keychain()
        let logger = Logger.shared

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

        guard let connection = WebSocketService.shared.connection else {
            return nil
        }

        let facade = UserDataStorageFacade.shared

        let filter = NSPredicate.filterAccountBy(networkType: networkType)
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            facade.createRepository(filter: filter,
                                    sortDescriptors: [.accountsByOrder])

        let view = StakingAmountViewController(nib: R.nib.stakingAmountViewController)

        let rewardDestViewModelFactory = RewardDestinationViewModelFactory(asset: asset)
        let balanceViewModelFactory = BalanceViewModelFactory(walletPrimitiveFactory: primitiveFactory,
                                                              selectedAddressType: networkType)
        let presenter = StakingAmountPresenter(asset: asset,
                                               selectedAccount: selectedAccount,
                                               rewardDestViewModelFactory: rewardDestViewModelFactory,
                                               balanceViewModelFactory: balanceViewModelFactory,
                                               applicationConfig: ApplicationConfig.shared,
                                               logger: logger)

        let priceProvider = providerFactory.getPriceProvider(for: assetId)

        let extrinsicService = ExtrinsicService(address: selectedAccount.address,
                                                cryptoType: selectedAccount.cryptoType,
                                                runtimeRegistry: RuntimeRegistryFacade.sharedService,
                                                engine: connection,
                                                operationManager: OperationManagerFacade.sharedManager)

        let interactor = StakingAmountInteractor(repository: AnyDataProviderRepository(accountRepository),
                                                 priceProvider: priceProvider,
                                                 balanceProvider: balanceProvider,
                                                 extrinsicService: extrinsicService,
                                                 operationManager: OperationManagerFacade.sharedManager)
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
}
