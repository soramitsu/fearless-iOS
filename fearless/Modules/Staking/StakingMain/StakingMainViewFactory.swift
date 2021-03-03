import Foundation
import SoraFoundation
import FearlessUtils
import SoraKeystore
import RobinHood

final class StakingMainViewFactory: StakingMainViewFactoryProtocol {
    static func createView() -> StakingMainViewProtocol? {
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

        // MARK: - Entity
        let facade = UserDataStorageFacade.shared
        let filter = NSPredicate.filterAccountBy(networkType: networkType)
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            facade.createRepository(filter: filter,
                                    sortDescriptors: [.accountsByOrder])

        // MARK: - View
        let view = StakingMainViewController(nib: R.nib.stakingMainViewController)
        view.localizationManager = LocalizationManager.shared
        view.iconGenerator = PolkadotIconGenerator()
        view.uiFactory = UIFactory()

        // MARK: - Interactor
        let providerFactory = SingleValueProviderFactory.shared

        guard let balanceProvider = try? providerFactory
                .getAccountProvider(for: selectedAccount.address,
                                    runtimeService: RuntimeRegistryFacade.sharedService) else {
            return nil
        }

        let priceProvider = providerFactory.getPriceProvider(for: assetId)

        let interactor = StakingMainInteractor(repository: AnyDataProviderRepository(accountRepository),
                                               priceProvider: priceProvider,
                                               balanceProvider: balanceProvider,
                                               settings: settings,
                                               eventCenter: EventCenter.shared,
                                               calculatorService: RewardCalculatorFacade.sharedService,
                                               operationManager: OperationManagerFacade.sharedManager,
                                               logger: logger)

        // MARK: - Presenter
        let balanceViewModelFactory = BalanceViewModelFactory(walletPrimitiveFactory: primitiveFactory,
                                                              selectedAddressType: networkType,
                                                              limit: StakingConstants.maxAmount)

        let rewardViewModelFactory = RewardViewModelFactory(walletPrimitiveFactory: primitiveFactory,
                                                            selectedAddressType: networkType)

        let presenter = StakingMainPresenter(logger: Logger.shared,
                                             asset: asset,
                                             balanceViewModelFactory: balanceViewModelFactory,
                                             rewardViewModelFactory: rewardViewModelFactory)

        // MARK: - Router
        let wireframe = StakingMainWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
