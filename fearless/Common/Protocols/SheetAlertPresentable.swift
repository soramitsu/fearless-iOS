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
        var currentController = view?.controller

        if currentController == nil {
            currentController = UIApplication.shared.delegate?.window??.rootViewController
        }

        guard let controller = currentController else {
            return
        }

        let sheetController = SheetAletViewController(viewModel: viewModel)
        sheetController.modalPresentationStyle = .custom
        let factory = ModalSheetBlurPresentationFactory(configuration: .fearlessBlur)
        sheetController.modalTransitioningFactory = factory

        controller.present(sheetController, animated: true)
    }
}
