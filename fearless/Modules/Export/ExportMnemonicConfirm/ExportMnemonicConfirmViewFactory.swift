import Foundation
import IrohaCrypto
import SoraFoundation

final class ExportMnemonicConfirmViewFactory: ExportMnemonicConfirmViewFactoryProtocol {
    static func createViewForMnemonic(_ mnemonic: IRMnemonicProtocol) -> AccountConfirmViewProtocol? {
        let view = AccountConfirmViewController(nib: R.nib.accountConfirmViewController)
        view.nextButtonTitle = LocalizableResource { locale in
            R.string.localizable.commonConfirm(preferredLanguages: locale.rLanguages)
        }

        let localizationManager = LocalizationManager.shared

        let presenter = AccountConfirmPresenter()

        let interactor = ExportMnemonicConfirmInteractor(mnemonic: mnemonic)
        let wireframe = ExportMnemonicConfirmWireframe(localizationManager: localizationManager)

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
