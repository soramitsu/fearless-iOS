import Foundation
import SoraFoundation

final class AddCustomNodePresenter {
    weak var view: AddCustomNodeViewProtocol?
    let wireframe: AddCustomNodeWireframeProtocol
    let interactor: AddCustomNodeInteractorInputProtocol
    weak var moduleOutput: AddCustomNodeModuleOutput?

    private var nameViewModel: InputViewModelProtocol
    private var nodeViewModel: InputViewModelProtocol

    let localizationManager: LocalizationManagerProtocol

    init(
        interactor: AddCustomNodeInteractorInputProtocol,
        wireframe: AddCustomNodeWireframeProtocol,
        localizationManager: LocalizationManagerProtocol,
        moduleOutput: AddCustomNodeModuleOutput?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.moduleOutput = moduleOutput

        let nameInputHandling = InputHandler(predicate: NSPredicate.notEmpty)
        nameViewModel = InputViewModel(inputHandler: nameInputHandling)

        let processor = TrimmingCharacterProcessor(charset: CharacterSet.whitespacesAndNewlines)
        let nodeInputHandling = InputHandler(
            predicate: NSPredicate.websocket,
            processor: processor
        )

        nodeViewModel = InputViewModel(inputHandler: nodeInputHandling)

        self.localizationManager = localizationManager
    }
}

extension AddCustomNodePresenter: AddCustomNodePresenterProtocol {
    func didLoad(view: AddCustomNodeViewProtocol) {
        view.didReceive(nameViewModel: nameViewModel)
        view.didReceive(nodeViewModel: nodeViewModel)
    }

    func didTapAddNodeButton() {
        guard
            nameViewModel.inputHandler.completed,
            nodeViewModel.inputHandler.completed,
            let url = URL(string: nodeViewModel.inputHandler.normalizedValue)
        else {
            return
        }

        interactor.addConnection(url: url, name: nameViewModel.inputHandler.value)
    }

    func didTapCloseButton() {
        wireframe.dismiss(view: view)
    }
}

extension AddCustomNodePresenter: AddCustomNodeInteractorOutputProtocol {
    func didStartAdding(url _: URL) {
        view?.didStartLoading()
    }

    func didCompleteAdding(url _: URL) {
        view?.didStopLoading()

        moduleOutput?.didChangedNodesList()

        wireframe.dismiss(view: view)
    }

    func didReceiveError(error: Error, for _: URL) {
        view?.didStopLoading()

        if !wireframe.present(
            error: error,
            from: view,
            locale: localizationManager.selectedLocale
        ) {
            _ = wireframe.present(
                error: CommonError.undefined,
                from: view,
                locale: localizationManager.selectedLocale
            )
        }
    }
}
