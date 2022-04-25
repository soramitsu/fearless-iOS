import Foundation

final class WarningAlertPresenter {
    weak var view: WarningAlertViewProtocol?
    private let wireframe: WarningAlertWireframeProtocol
    private let interactor: WarningAlertInteractorInputProtocol
    private let alertConfig: WarningAlertConfig
    private let buttonHandler: WarningAlertButtonHandler

    init(
        interactor: WarningAlertInteractorInputProtocol,
        wireframe: WarningAlertWireframeProtocol,
        alertConfig: WarningAlertConfig,
        buttonHandler: @escaping WarningAlertButtonHandler
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.alertConfig = alertConfig
        self.buttonHandler = buttonHandler
    }
}

extension WarningAlertPresenter: WarningAlertPresenterProtocol {
    func didLoad(view: WarningAlertViewProtocol) {
        self.view = view

        view.didReceive(config: alertConfig)
    }

    func didTapActionButton() {
        buttonHandler()
    }

    func didTapCloseButton() {
        wireframe.dismiss(view: view)
    }
}

extension WarningAlertPresenter: WarningAlertInteractorOutputProtocol {}
