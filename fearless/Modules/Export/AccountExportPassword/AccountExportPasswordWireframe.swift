import Foundation

final class AccountExportPasswordWireframe: AccountExportPasswordWireframeProtocol {
    func showJSONExport(_ json: String, from view: AccountExportPasswordViewProtocol?) {
        // TODO: FLW - 420
        Logger.shared.debug("Did receive json: \(json)")
    }
}
