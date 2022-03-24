import Foundation

struct WarningAlertViewFactory {
    static func createView(
        alertConfig: WarningAlertConfig,
        buttonHandler: @escaping () -> Void
    ) -> WarningAlertViewProtocol? {
        let interactor = WarningAlertInteractor()
        let wireframe = WarningAlertWireframe()

        let presenter = WarningAlertPresenter(
            interactor: interactor,
            wireframe: wireframe,
            alertConfig: alertConfig,
            buttonHandler: buttonHandler
        )

        let view = WarningAlertViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
