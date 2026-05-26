import Foundation
import IrohaCrypto

final class ExportMnemonicWireframe: ExportMnemonicWireframeProtocol {
    func openConfirmationForMnemonics(
        _ mnemonics: [IRMnemonicProtocol],
        wallet: MetaAccountModel,
        from view: ExportGenericViewProtocol?
    ) {
        guard let confirmationView = ExportMnemonicConfirmViewFactory.createViewForMnemonics(
            mnemonics,
            wallet: wallet
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
