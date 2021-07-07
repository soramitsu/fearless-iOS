import Foundation
import SoraKeystore
import RobinHood
import SoraFoundation

struct SignerConnectViewFactory {
    static func createBeaconView(for info: BeaconConnectionInfo) -> SignerConnectViewProtocol? {
        let settings = SettingsManager.shared

        guard let selectedAccount = settings.selectedAccount else {
            return nil
        }

        let interactor = SignerConnectInteractor(
            selectedAccount: selectedAccount,
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

        let view = SignerConnectViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
