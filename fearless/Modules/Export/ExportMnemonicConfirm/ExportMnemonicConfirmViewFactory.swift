import Foundation
import IrohaCrypto
import FearlessFoundation

final class ExportMnemonicConfirmViewFactory: ExportMnemonicConfirmViewFactoryProtocol {
    static func createViewForMnemonics(
        _ mnemonics: [IRMnemonicProtocol],
        wallet: MetaAccountModel
    ) -> AccountConfirmViewProtocol? {
        guard mnemonics.isNotEmpty else {
            return nil
        }

        let view = AccountConfirmViewController(nib: R.nib.accountConfirmViewController)
        view.nextButtonTitle = LocalizableResource { locale in
            R.string.localizable.commonConfirm(preferredLanguages: locale.rLanguages)
        }

        let localizationManager = LocalizationManager.shared
        let interactor = ExportMnemonicConfirmInteractor(
            mnemonics: mnemonics,
            settings: SelectedWalletSettings.shared,
            wallet: wallet,
            eventCenter: EventCenter.shared
        )
        let wireframe = ExportMnemonicConfirmWireframe(localizationManager: localizationManager)

        let presenter = AccountConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager
        )

        view.presenter = presenter
        presenter.view = view
        interactor.presenter = presenter

        view.localizationManager = localizationManager

        return view
    }
}
