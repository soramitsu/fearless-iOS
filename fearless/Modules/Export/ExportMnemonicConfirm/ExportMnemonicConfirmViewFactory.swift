import Foundation
import IrohaCrypto
import SoraFoundation

final class ExportMnemonicConfirmViewFactory: ExportMnemonicConfirmViewFactoryProtocol {
    static func createViewForMnemonic(_ mnemonic: IRMnemonicProtocol) -> AccountConfirmViewProtocol? {
        let view = AccountConfirmViewController(nib: R.nib.accountConfirmViewController)
        let presenter = AccountConfirmPresenter()

        let interactor = ExportMnemonicConfirmInteractor(mnemonic: mnemonic)
        let wireframe = ExportMnemonicConfirmWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        let localizationManager = LocalizationManager.shared
        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager

        return view
    }

}
