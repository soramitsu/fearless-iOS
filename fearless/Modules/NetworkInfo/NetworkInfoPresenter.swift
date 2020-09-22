import Foundation
import SoraFoundation

final class NetworkInfoPresenter {
    weak var view: NetworkInfoViewProtocol?
    var wireframe: NetworkInfoWireframeProtocol!
    var interactor: NetworkInfoInteractorInputProtocol!

    private let nameViewModel: InputViewModelProtocol
    private let nodeViewModel: InputViewModelProtocol

    let connectionItem: ConnectionItem

    let localizationManager: LocalizationManagerProtocol

    init(connectionItem: ConnectionItem, readOnly: Bool, localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager

        self.connectionItem = connectionItem

        let nameInputHandling = InputHandler(value: connectionItem.title, enabled: !readOnly)
        nameViewModel = InputViewModel(inputHandler: nameInputHandling)

        let nodeInputHandling = InputHandler(value: connectionItem.identifier, enabled: !readOnly)
        nodeViewModel = InputViewModel(inputHandler: nodeInputHandling)
    }
}

extension NetworkInfoPresenter: NetworkInfoPresenterProtocol {
    func setup() {
        view?.set(nameViewModel: nameViewModel)
        view?.set(nodeViewModel: nodeViewModel)
    }

    func activateCopy() {
        UIPasteboard.general.string = nodeViewModel.inputHandler.value

        let locale = localizationManager.selectedLocale
        let title = R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages)
        wireframe.presentSuccessNotification(title, from: view)
    }

    func activateClose() {
        wireframe.close(view: view)
    }
}

extension NetworkInfoPresenter: NetworkInfoInteractorOutputProtocol {}
