import Foundation

final class ExportMnemonicConfirmWireframe: AccountConfirmWireframeProtocol {
    func proceed(from view: AccountConfirmViewProtocol?) {
        view?.controller.navigationController?.popToRootViewController(animated: true)
    }
}
