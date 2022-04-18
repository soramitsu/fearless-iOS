import Foundation
import IrohaCrypto

final class ExportMnemonicWireframe: ExportMnemonicWireframeProtocol {
    func openConfirmationForMnemonic(
        _ mnemonic: IRMnemonicProtocol,
        from view: ExportGenericViewProtocol?
    ) {
        guard let confirmationView = ExportMnemonicConfirmViewFactory.createViewForMnemonic(mnemonic) else {
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
