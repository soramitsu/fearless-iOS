import UIKit
import SoraFoundation
import SoraKeystore
import IrohaCrypto
import FearlessUtils

final class ProfileViewFactory: ProfileViewFactoryProtocol {
    static func createView() -> ProfileViewProtocol? {
        let localizationManager = LocalizationManager.shared

        let profileViewModelFactory = ProfileViewModelFactory(iconGenerator: PolkadotIconGenerator())

        let view = ProfileViewController(nib: R.nib.profileViewController)
        view.iconGenerating = PolkadotIconGenerator()

        let presenter = ProfilePresenter(viewModelFactory: profileViewModelFactory)

        let interactor = ProfileInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared
        )

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
