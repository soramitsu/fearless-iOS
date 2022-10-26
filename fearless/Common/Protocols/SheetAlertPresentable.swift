import Foundation
import UIKit

struct SheetAlertPresentableAction {
    let title: String
    let style: TriangularedButton

    let handler: (() -> Void)?
}

struct SheetAlertPresentableViewModel {
    let title: String
    let titleStyle: SheetAlertPresentableStyle
    let subtitle: String?
    let subtitleStyle: SheetAlertPresentableStyle?
    let actions: [SheetAlertPresentableAction]
    let dismissCompletion: (() -> Void)?

    init(
        title: String,
        titleStyle: SheetAlertPresentableStyle = .defaultTitle,
        subtitle: String?,
        subtitleStyle: SheetAlertPresentableStyle? = .defaultSubtitle,
        actions: [SheetAlertPresentableAction],
        dismissCompletion: (() -> Void)? = nil
    ) {
        self.title = title
        self.titleStyle = titleStyle
        self.subtitle = subtitle
        self.subtitleStyle = subtitleStyle
        self.actions = actions
        self.dismissCompletion = dismissCompletion
    }
}

protocol SheetAlertPresentable {
    func present(
        viewModel: SheetAlertPresentableViewModel,
        from view: ControllerBackedProtocol?
    )
}

extension SheetAlertPresentable {
    func present(
        viewModel: SheetAlertPresentableViewModel,
        from view: ControllerBackedProtocol?
    ) {
        guard let controller = view?.controller else {
            return
        }

        let sheetController = SheetAletViewController(viewModel: viewModel)
        sheetController.modalPresentationStyle = .custom
        let factory = ModalSheetBlurPresentationFactory(configuration: .fearlessBlur)
        sheetController.modalTransitioningFactory = factory

        controller.present(sheetController, animated: true)
    }
}
