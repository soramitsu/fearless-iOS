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

        let primitiveFactory = WalletPrimitiveFactory(keystore: keystore, settings: settings)

        // MARK: - View
        let view = StakingMainViewController(nib: R.nib.stakingMainViewController)
        view.localizationManager = LocalizationManager.shared
        view.iconGenerator = PolkadotIconGenerator()
        view.uiFactory = UIFactory()

        // MARK: - Interactor
        let substrateProviderFactory =
            SubstrateDataProviderFactory(facade: SubstrateDataStorageFacade.shared,
                                         operationManager: OperationManagerFacade.sharedManager)

        let interactor = StakingMainInteractor(providerFactory: SingleValueProviderFactory.shared,
                                               substrateProviderFactory: substrateProviderFactory,
                                               settings: settings,
                                               eventCenter: EventCenter.shared,
                                               primitiveFactory: primitiveFactory,
                                               calculatorService: RewardCalculatorFacade.sharedService,
                                               runtimeService: RuntimeRegistryFacade.sharedService,
                                               operationManager: OperationManagerFacade.sharedManager,
                                               logger: logger)

        // MARK: - Presenter

        let viewModelFacade = StakingViewModelFacade(primitiveFactory: primitiveFactory)
        let presenter = StakingMainPresenter(viewModelFacade: viewModelFacade,
                                             logger: logger)

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
