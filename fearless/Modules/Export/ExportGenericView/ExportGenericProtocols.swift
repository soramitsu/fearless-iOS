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

extension ExportGenericPresenterProtocol {
    func activateAccessoryOption() {}
}

protocol ExportGenericWireframeProtocol: ErrorPresentable, AlertPresentable, SharingPresentable {
    func close(view: ExportGenericViewProtocol?)
}

extension ExportGenericWireframeProtocol {
    func close(view: ExportGenericViewProtocol?) {
        view?.controller.navigationController?.popToRootViewController(animated: true)
    }
}
