import Foundation
import SoraKeystore
import RobinHood

struct SignerConnectViewFactory {
    static func createBeaconView(for info: BeaconConnectionInfo) -> SignerConnectViewProtocol? {
        let settings = SettingsManager.shared
        guard let selectedAddress = settings.selectedAccount?.address else {
            return nil
        }

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        let signingWrapper = SigningWrapper(keystore: Keychain(), settings: settings)

        let runtimeService = RuntimeRegistryFacade.sharedService

        let interactor = SignerConnectInteractor(
            selectedAddress: selectedAddress,
            accountRepository: AnyDataProviderRepository(accountRepository),
            operationManager: OperationManagerFacade.sharedManager,
            signingWrapper: signingWrapper,
            runtimeService: runtimeService,
            info: info,
            logger: Logger.shared
        )

        let wireframe = SignerConnectWireframe()

        let viewModelFactory = SignerConnectViewModelFactory()
        let presenter = SignerConnectPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chain: settings.selectedConnection.type.chain
        )

        let view = SignerConnectViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
