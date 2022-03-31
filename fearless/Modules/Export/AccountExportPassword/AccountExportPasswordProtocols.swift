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
    func exportWallet(_ account: MetaAccountModel)
    func exportAccount(address: String, password: String, chain: ChainModel)
}

protocol AccountExportPasswordInteractorOutputProtocol: AnyObject {
    func didExport(jsons: [RestoreJson])
    func didReceive(error: Error)
}

protocol AccountExportPasswordWireframeProtocol: ErrorPresentable, AlertPresentable {
    func showJSONExport(_ jsons: [RestoreJson], from view: AccountExportPasswordViewProtocol?)
}

protocol AccountExportPasswordViewFactoryProtocol: AnyObject {
    static func createView(flow: ExportFlow) -> AccountExportPasswordViewProtocol?
}
