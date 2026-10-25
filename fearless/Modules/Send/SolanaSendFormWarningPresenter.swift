import Foundation

/// Routes the existing validator's warning through one exact form receipt.
/// Other validator callers retain their original presentation behavior.
final class SolanaSendFormWarningPresenter: SheetAlertPresentable {
    private let presentation: (SheetAlertPresentableViewModel, ControllerBackedProtocol?) -> Void

    init(presentation: @escaping (SheetAlertPresentableViewModel, ControllerBackedProtocol?) -> Void) {
        self.presentation = presentation
    }

    func present(viewModel: SheetAlertPresentableViewModel, from view: ControllerBackedProtocol?) {
        presentation(viewModel, view)
    }
}
