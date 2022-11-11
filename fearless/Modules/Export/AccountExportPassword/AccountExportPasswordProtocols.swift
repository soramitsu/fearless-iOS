import Foundation
import SoraFoundation

protocol AccountExportPasswordViewProtocol: ControllerBackedProtocol {
    func setPasswordInputViewModel(_ viewModel: InputViewModelProtocol)
    func setPasswordConfirmationViewModel(_ viewModel: InputViewModelProtocol)
    func set(error: AccountExportPasswordError)
}

protocol AccountExportPasswordPresenterProtocol: AnyObject {
    var flow: ExportFlow { get }

    func setup()
    func proceed()
}

protocol AccountExportPasswordInteractorInputProtocol: AnyObject {
    func exportWallet(
        wallet: MetaAccountModel,
        accounts: [ChainAccountInfo],
        password: String
    )

    func exportAccount(
        address: String,
        password: String,
        chain: ChainModel,
        wallet: MetaAccountModel
    )
}

protocol AccountExportPasswordInteractorOutputProtocol: AnyObject {
    func didExport(jsons: [RestoreJson])
    func didReceive(error: Error)
}

protocol AccountExportPasswordWireframeProtocol: ErrorPresentable, SheetAlertPresentable {
    func showJSONExport(_ jsons: [RestoreJson], flow: ExportFlow, from view: AccountExportPasswordViewProtocol?)
    func back(from view: ControllerBackedProtocol?)
}

protocol AccountExportPasswordViewFactoryProtocol: AnyObject {
    static func createView(flow: ExportFlow) -> AccountExportPasswordViewProtocol?
}
