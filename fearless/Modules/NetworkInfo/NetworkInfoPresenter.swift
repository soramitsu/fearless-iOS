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

    init(connectionItem: ConnectionItem,
         mode: NetworkInfoMode,
         localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager

        self.connectionItem = connectionItem

        let nameInputHandling = InputHandler(value: connectionItem.title, enabled: mode.contains(.name))
        nameViewModel = InputViewModel(inputHandler: nameInputHandling)

        let processor = TrimmingCharacterProcessor(charset: CharacterSet.whitespacesAndNewlines)
        let nodeInputHandling = InputHandler(value: connectionItem.identifier,
                                             enabled: mode.contains(.node),
                                             predicate: NSPredicate.websocket,
                                             processor: processor)
        nodeViewModel = InputViewModel(inputHandler: nodeInputHandling)
    }
}

extension NetworkInfoPresenter: NetworkInfoPresenterProtocol {
    func setup() {
        view?.set(nameViewModel: nameViewModel)
        view?.set(nodeViewModel: nodeViewModel)
    }

    func activateCopy() {
        UIPasteboard.general.string = nodeViewModel.inputHandler.normalizedValue

        let locale = localizationManager.selectedLocale
        let title = R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages)
        wireframe.presentSuccessNotification(title, from: view)
    }

    func activateClose() {
        wireframe.close(view: view)
    }

    func activateUpdate() {
        guard let url = URL(string: nodeViewModel.inputHandler.normalizedValue) else {
            return
        }

        interactor.updateConnection(connectionItem,
                                    newURL: url,
                                    newName: nodeViewModel.inputHandler.value)
    }
}

extension NetworkInfoPresenter: NetworkInfoInteractorOutputProtocol {
    func didStartConnectionUpdate(with url: URL) {
        view?.didStartLoading()
    }

    func didCompleteConnectionUpdate(with url: URL) {
        view?.didStopLoading()

        wireframe.close(view: view)
    }

    func didReceive(error: Error, for url: URL) {
        view?.didStopLoading()

        if !wireframe.present(error: error,
                              from: view,
                              locale: localizationManager.selectedLocale) {
            _ = wireframe.present(error: CommonError.undefined,
                                  from: view,
                                  locale: localizationManager.selectedLocale)
        }
    }
}
