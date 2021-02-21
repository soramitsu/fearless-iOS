import Foundation
import SoraKeystore
import RobinHood
import SoraFoundation

final class StakingAmountViewFactory: StakingAmountViewFactoryProtocol {
    static func createView() -> StakingAmountViewProtocol? {
        let settings = SettingsManager.shared
        let keystore = Keychain()
        let logger = Logger.shared

        guard let selectedAccount = settings.selectedAccount else {
            return nil
        }

        let networkType = settings.selectedConnection.type
        let facade = UserDataStorageFacade.shared

        let filter = NSPredicate.filterAccountBy(networkType: networkType)
        let mapper = ManagedAccountItemMapper()
        let accountRepository = facade.createRepository(filter: filter,
                                                        sortDescriptors: [.accountsByOrder],
                                                        mapper: AnyCoreDataMapper(mapper))

        let view = StakingAmountViewController(nib: R.nib.stakingAmountViewController)

        let asset = WalletPrimitiveFactory(keystore: keystore, settings: settings)
            .createAssetForAddressType(networkType)
        let rewardDestViewModelFactory = RewardDestinationViewModelFactory(asset: asset)
        let presenter = StakingAmountPresenter(selectedAccount: selectedAccount,
                                               rewardDestViewModelFactory: rewardDestViewModelFactory,
                                               logger: logger)
        let interactor = StakingAmountInteractor(repository: AnyDataProviderRepository(accountRepository),
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
