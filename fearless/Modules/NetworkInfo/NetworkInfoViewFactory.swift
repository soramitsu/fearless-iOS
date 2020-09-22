import Foundation
import SoraFoundation

final class NetworkInfoViewFactory: NetworkInfoViewFactoryProtocol {
    static func createView(with connectionItem: ConnectionItem, readOnly: Bool) -> NetworkInfoViewProtocol? {
        let view = NetworkInfoViewController(nib: R.nib.networkInfoViewController)
        let presenter = NetworkInfoPresenter(connectionItem: connectionItem,
                                             readOnly: readOnly,
                                             localizationManager: LocalizationManager.shared)
        let interactor = NetworkInfoInteractor()
        let wireframe = NetworkInfoWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
