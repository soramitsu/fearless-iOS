import UIKit
import SoraFoundation
import SoraKeystore
import IrohaCrypto

final class ProfileViewFactory: ProfileViewFactoryProtocol {
	static func createView() -> ProfileViewProtocol? {
        let localizationManager = LocalizationManager.shared

        let profileViewModelFactory = ProfileViewModelFactory()

        let view = ProfileViewController(nib: R.nib.profileViewController)
        let presenter = ProfilePresenter(viewModelFactory: profileViewModelFactory)
        let interactor = ProfileInteractor(settingsManager: SettingsManager.shared,
                                           ss58AddressFactory: SS58AddressFactory(),
                                           logger: Logger.shared)
        let wireframe = ProfileWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager
        presenter.logger = Logger.shared

        return view
	}
}
