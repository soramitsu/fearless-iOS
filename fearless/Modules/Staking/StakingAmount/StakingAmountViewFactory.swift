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

        let facade = UserDataStorageFacade.shared

        let filter = NSPredicate.filterAccountBy(networkType: networkType)
        let mapper = ManagedAccountItemMapper()
        let accountRepository = facade.createRepository(filter: filter,
                                                        sortDescriptors: [.accountsByOrder],
                                                        mapper: AnyCoreDataMapper(mapper))

        let view = StakingAmountViewController(nib: R.nib.stakingAmountViewController)

        let rewardDestViewModelFactory = RewardDestinationViewModelFactory(asset: asset)
        let balanceViewModelFactory = BalanceViewModelFactory(walletPrimitiveFactory: primitiveFactory,
                                                              selectedAddressType: networkType)
        let presenter = StakingAmountPresenter(selectedAccount: selectedAccount,
                                               rewardDestViewModelFactory: rewardDestViewModelFactory,
                                               balanceViewModelFactory: balanceViewModelFactory,
                                               logger: logger)

        let priceProvider = SingleValueProviderFactory.shared.getPriceProvider(for: assetId)
        let interactor = StakingAmountInteractor(repository: AnyDataProviderRepository(accountRepository),
                                                 priceProvider: priceProvider,
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
