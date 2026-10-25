import Foundation
import IrohaCrypto
import SoraFoundation

final class ExportMnemonicConfirmViewFactory: ExportMnemonicConfirmViewFactoryProtocol {
    static func createViewForMnemonic(
        _ mnemonic: IRMnemonicProtocol,
        wallet: MetaAccountModel
    ) -> AccountConfirmViewProtocol? {
        createViewForMnemonic(mnemonic, wallet: wallet, backupProof: nil)
    }

    static func createViewForMnemonic(
        _ mnemonic: IRMnemonicProtocol,
        wallet: MetaAccountModel,
        backupProof: VerifiedMnemonicBackup?,
        settings: SelectedWalletSettings = .shared,
        eventCenter: EventCenterProtocol = EventCenter.shared
    ) -> AccountConfirmViewProtocol? {
        let view = AccountConfirmViewController(nib: R.nib.accountConfirmViewController)
        view.showsExactMnemonicSpacing = mnemonic is LegacyTonMnemonic && mnemonic.allWords().contains {
            $0.isEmpty || $0.unicodeScalars.contains { CharacterSet.whitespacesAndNewlines.contains($0) }
        }
        view.nextButtonTitle = LocalizableResource { locale in
            R.string.localizable.commonConfirm(preferredLanguages: locale.rLanguages)
        }

        let localizationManager = LocalizationManager.shared
        let interactor = ExportMnemonicConfirmInteractor(
            mnemonic: mnemonic,
            settings: settings,
            wallet: wallet,
            eventCenter: eventCenter,
            recordsWholeWalletBackup: backupProof?.covers(mnemonic, wallet: wallet) == true
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
