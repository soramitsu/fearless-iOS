import Foundation
import SoraFoundation

protocol AccountExportPasswordViewProtocol: ControllerBackedProtocol {
    func setPasswordInputViewModel(_ viewModel: InputViewModelProtocol)
    func setPasswordConfirmationViewModel(_ viewModel: InputViewModelProtocol)
    func set(error: AccountExportPasswordError)
}

protocol AccountExportPasswordPresenterProtocol: class {
    func setup()
    func proceed()
}

protocol AccountExportPasswordInteractorInputProtocol: class {}

protocol AccountExportPasswordInteractorOutputProtocol: class {}

protocol AccountExportPasswordWireframeProtocol: class {}

protocol AccountExportPasswordViewFactoryProtocol: class {
    static func createView(with address: String) -> AccountExportPasswordViewProtocol?
}
