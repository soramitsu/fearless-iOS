import Foundation
import SoraFoundation
import SSFModels

final class NetworkInfoPresenter {
    weak var view: NetworkInfoViewProtocol?
    var wireframe: NetworkInfoWireframeProtocol!
    var interactor: NetworkInfoInteractorInputProtocol!

    private let nameViewModel: InputViewModelProtocol
    private let nodeViewModel: InputViewModelProtocol

    let node: ChainNodeModel
    let chain: ChainModel

    let localizationManager: LocalizationManagerProtocol

    init(
        chain: ChainModel,
        node: ChainNodeModel,
        mode: NetworkInfoMode,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.localizationManager = localizationManager

        self.node = node
        self.chain = chain

        let nameInputHandling = InputHandler(value: node.name, enabled: mode.contains(.name))
        nameViewModel = InputViewModel(inputHandler: nameInputHandling)

        let processor = TrimmingCharacterProcessor(charset: CharacterSet.whitespacesAndNewlines)
        let nodeInputHandling = InputHandler(
            value: node.clearUrlString ?? "",
            enabled: mode.contains(.node),
            predicate: NSPredicate.websocket,
            processor: processor
        )
        nodeViewModel = InputViewModel(inputHandler: nodeInputHandling)
    }
}

extension NetworkInfoPresenter: NetworkInfoPresenterProtocol {
    func setup() {
        view?.set(nameViewModel: nameViewModel)
        view?.set(nodeViewModel: nodeViewModel)
        view?.set(chain: chain)
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

        interactor.updateNode(
            node,
            newURL: url,
            newName: nameViewModel.inputHandler.value
        )
    }
}

extension NetworkInfoPresenter: NetworkInfoInteractorOutputProtocol {
    func didStartConnectionUpdate(with _: URL) {
        view?.didStartLoading()
    }

    func didCompleteConnectionUpdate(with _: URL) {
        view?.didStopLoading()

        wireframe.close(view: view)
    }

    func didReceive(error: Error, for _: URL) {
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
