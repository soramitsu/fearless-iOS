import Foundation

final class WarningAlertPresenter {
    weak var view: WarningAlertViewProtocol?
    let wireframe: WarningAlertWireframeProtocol
    let interactor: WarningAlertInteractorInputProtocol
    let alertConfig: WarningAlertConfig
    let buttonHandler: WarningAlertButtonHandler

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
    func setup() {
        view?.didReceive(config: alertConfig)
    }

    func didTapActionButton() {
        buttonHandler()
    }

    func didTapCloseButton() {
        wireframe.dismiss(view: view)
    }
}

extension WarningAlertPresenter: WarningAlertInteractorOutputProtocol {}
