import Foundation
import SoraFoundation

protocol ExportGenericViewProtocol: ControllerBackedProtocol {
    func set(viewModel: ExportGenericViewModelProtocol)
}

protocol ExportGenericPresenterProtocol {
    func setup()
    func activateExport()
    func activateAccessoryOption()
}
