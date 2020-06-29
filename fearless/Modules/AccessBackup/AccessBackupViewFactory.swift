import Foundation
import SoraKeystore
import IrohaCrypto
import SoraFoundation

final class AccessBackupViewFactory: AccessBackupViewFactoryProtocol {
    static func createView() -> AccessBackupViewProtocol? {
        let localizationManager = LocalizationManager.shared

        let view = AccessBackupViewController(nib: R.nib.accessBackupViewController)
        view.mode = .registration

        let presenter = AccessBackupPresenter()
        let interactor = AccessBackupInteractor(keystore: Keychain(),
                                                mnemonicCreator: IRMnemonicCreator(language: .english))
        let wireframe = AccessBackupWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager

        return view
    }
}
