import Foundation
import UIKit

struct SheetAlertPresentableAction {
    let title: String
    let button: TriangularedButton

    let handler: (() -> Void)?

    init(
        title: String,
        button: TriangularedButton = UIFactory.default.createMainActionButton(),
        handler: (() -> Void)? = nil
    ) {
        self.title = title
        self.button = button
        self.handler = handler
    }
}

struct SheetAlertPresentableViewModel {
    let title: String
    let titleStyle: SheetAlertPresentableStyle
    let message: String?
    let messageStyle: SheetAlertPresentableStyle?
    let actions: [SheetAlertPresentableAction]
    let closeAction: String?
    let dismissCompletion: (() -> Void)?

    init(
        title: String,
        titleStyle: SheetAlertPresentableStyle = .defaultTitle,
        message: String?,
        messageStyle: SheetAlertPresentableStyle? = .defaultSubtitle,
        actions: [SheetAlertPresentableAction],
        closeAction: String?,
        dismissCompletion: (() -> Void)? = nil
    ) {
        self.title = title
        self.titleStyle = titleStyle
        self.message = message
        self.messageStyle = messageStyle
        self.actions = actions
        self.closeAction = closeAction
        self.dismissCompletion = dismissCompletion
    }
}

protocol SheetAlertPresentable: BaseErrorPresentable, ErrorPresentable {
    func present(
        viewModel: SheetAlertPresentableViewModel,
        from view: ControllerBackedProtocol?
    )

    func present(
        message: String?,
        title: String,
        closeAction: String?,
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

    func present(
        message: String?,
        title: String,
        closeAction: String?,
        from view: ControllerBackedProtocol?
    ) {
        guard let controller = view?.controller else {
            return
        }

        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: closeAction
        )
        let sheetController = SheetAletViewController(viewModel: viewModel)
        sheetController.modalPresentationStyle = .custom
        let factory = ModalSheetBlurPresentationFactory(configuration: .fearlessBlur)
        sheetController.modalTransitioningFactory = factory

        controller.present(sheetController, animated: true)
    }
}
