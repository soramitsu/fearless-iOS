import Foundation
import IrohaCrypto

final class ExportMnemonicWireframe: ExportMnemonicWireframeProtocol {
    func openConfirmationForMnemonic(
        _ mnemonic: IRMnemonicProtocol,
        wallet: MetaAccountModel,
        from view: ExportGenericViewProtocol?
    ) {
        openConfirmationForMnemonic(mnemonic, wallet: wallet, backupProof: nil, from: view)
    }

    func openConfirmationForMnemonic(
        _ mnemonic: IRMnemonicProtocol,
        wallet: MetaAccountModel,
        backupProof: VerifiedMnemonicBackup?,
        from view: ExportGenericViewProtocol?
    ) {
        guard let confirmationView = ExportMnemonicConfirmViewFactory.createViewForMnemonic(
            mnemonic, wallet: wallet, backupProof: backupProof
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmationView.controller,
            animated: true
        )
    }

    func back(view: ExportGenericViewProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
