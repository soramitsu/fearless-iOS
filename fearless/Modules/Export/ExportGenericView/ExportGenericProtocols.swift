import Foundation
import SoraFoundation

protocol ExportGenericViewProtocol: ControllerBackedProtocol {
    func showBackupStatusFailure(retry: @escaping () -> Void)
    func set(viewModel: MultipleExportGenericViewModelProtocol)
}

extension ExportGenericViewProtocol {
    func showBackupStatusFailure(retry _: @escaping () -> Void) {}
}

protocol ExportGenericPresenterProtocol {
    var flow: ExportFlow { get }

    func didLeaveView()
    func didLoadView()
    func setup()
    func activateExport()
    func activateAccessoryOption()
    func didTapExportSubstrateButton()
    func didTapExportEthereumButton()
    func didTapStringExport(_ value: String?)
}

extension ExportGenericPresenterProtocol {
    func didLeaveView() {}
    func activateAccessoryOption() {}
    func activateExport() {}
    func didTapExportSubstrateButton() {}
    func didTapExportEthereumButton() {}
    func didTapStringExport(_: String?) {}
}

protocol ExportGenericWireframeProtocol: ErrorPresentable, SheetAlertPresentable, SharingPresentable {
    func presentBackupStatusFailure(
        from view: ExportGenericViewProtocol?, locale: Locale, retry: @escaping () -> Void
    )
    func close(view: ExportGenericViewProtocol?)
    func back(view: ExportGenericViewProtocol?)
}

extension ExportGenericWireframeProtocol {
    func presentBackupStatusFailure(
        from view: ExportGenericViewProtocol?, locale _: Locale, retry: @escaping () -> Void
    ) {
        view?.showBackupStatusFailure(retry: retry)
    }

    func close(view: ExportGenericViewProtocol?) {
        view?.controller.navigationController?.popToRootViewController(animated: true)
    }
}
