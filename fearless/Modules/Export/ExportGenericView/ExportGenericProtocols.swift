import Foundation
import SoraFoundation

protocol ExportGenericViewProtocol: ControllerBackedProtocol {
    func set(viewModel: MultipleExportGenericViewModelProtocol)
}

protocol ExportGenericPresenterProtocol {
    var flow: ExportFlow { get }

    func didLoadView()
    func setup()
    func activateExport()
    func activateAccessoryOption()
    func didTapExportSubstrateButton()
    func didTapExportEthereumButton()
    func didTapStringExport(_ value: String?)
}

extension ExportGenericPresenterProtocol {
    func activateAccessoryOption() {}
    func activateExport() {}
    func didTapExportSubstrateButton() {}
    func didTapExportEthereumButton() {}
    func didTapStringExport(_: String?) {}
}

protocol ExportGenericWireframeProtocol: ErrorPresentable, SheetAlertPresentable, SharingPresentable {
    func close(view: ExportGenericViewProtocol?)
    func back(view: ExportGenericViewProtocol?)
}

extension ExportGenericWireframeProtocol {
    func close(view: ExportGenericViewProtocol?) {
        view?.controller.navigationController?.popToRootViewController(animated: true)
    }
}
