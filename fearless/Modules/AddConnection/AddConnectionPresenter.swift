import Foundation
import SoraFoundation

final class AddConnectionPresenter {
    weak var view: AddConnectionViewProtocol?
    var wireframe: AddConnectionWireframeProtocol!
    var interactor: AddConnectionInteractorInputProtocol!

    private var nameViewModel: InputViewModelProtocol
    private var nodeViewModel: InputViewModelProtocol

    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager

        let nameInputHandling = InputHandler(predicate: NSPredicate.notEmpty)
        nameViewModel = InputViewModel(inputHandler: nameInputHandling)

        let processor = TrimmingCharacterProcessor(charset: CharacterSet.whitespacesAndNewlines)
        let nodeInputHandling = InputHandler(predicate: NSPredicate.websocket,
                                             processor: processor)
        nodeViewModel = InputViewModel(inputHandler: nodeInputHandling)
    }

}

extension AddConnectionPresenter: AddConnectionPresenterProtocol {
    func setup() {
        view?.set(nameViewModel: nameViewModel)
        view?.set(nodeViewModel: nodeViewModel)
    }

    func add() {
        guard
            nameViewModel.inputHandler.completed,
            nodeViewModel.inputHandler.completed,
            let url = URL(string: nodeViewModel.inputHandler.normalizedValue) else {
            return
        }

        interactor.addConnection(url: url, name: nameViewModel.inputHandler.value)
    }
}

extension AddConnectionPresenter: AddConnectionInteractorOutputProtocol {
    func didStartAdding(url: URL) {
        view?.didStartLoading()
    }

    func didCompleteAdding(url: URL) {
        view?.didStopLoading()

        wireframe.close(view: view)
    }

    func didReceiveError(error: Error, for url: URL) {
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
