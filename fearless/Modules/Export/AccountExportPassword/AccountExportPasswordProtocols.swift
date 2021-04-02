import Foundation
import SoraFoundation

protocol AccountExportPasswordViewProtocol: ControllerBackedProtocol {
    func setPasswordInputViewModel(_ viewModel: InputViewModelProtocol)
    func setPasswordConfirmationViewModel(_ viewModel: InputViewModelProtocol)
    func set(error: AccountExportPasswordError)
}

protocol AccountExportPasswordPresenterProtocol: AnyObject {
    func setup()
    func proceed()
}

protocol AccountExportPasswordInteractorInputProtocol: AnyObject {
    func exportAccount(address: String, password: String)
}

protocol AccountExportPasswordInteractorOutputProtocol: AnyObject {
    func didExport(json: RestoreJson)
    func didReceive(error: Error)
}

protocol AccountExportPasswordWireframeProtocol: ErrorPresentable, AlertPresentable {
    func showJSONExport(_ json: RestoreJson, from view: AccountExportPasswordViewProtocol?)
}

protocol AccountExportPasswordViewFactoryProtocol: AnyObject {
    static func createView(with address: String) -> AccountExportPasswordViewProtocol?
}
