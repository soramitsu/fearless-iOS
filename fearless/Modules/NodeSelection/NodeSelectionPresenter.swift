import Foundation
import SoraFoundation

final class NodeSelectionPresenter {
    weak var view: NodeSelectionViewProtocol?
    let wireframe: NodeSelectionWireframeProtocol
    let interactor: NodeSelectionInteractorInputProtocol
    let viewModelFactory: NodeSelectionViewModelFactoryProtocol

    init(
        interactor: NodeSelectionInteractorInputProtocol,
        wireframe: NodeSelectionWireframeProtocol,
        viewModelFactory: NodeSelectionViewModelFactoryProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.localizationManager = localizationManager
    }
}

extension NodeSelectionPresenter: NodeSelectionPresenterProtocol {
    func didChangeValueForAutomaticNodeSwitch(isOn: Bool) {
        interactor.setAutomaticSwitchNodes(isOn)
    }

    func setup() {
        interactor.setup()
    }

    func didSelectNode(_ node: ChainNodeModel) {
        interactor.selectNode(node)
    }

    func didTapCloseButton() {
        wireframe.dismiss(view: view)
    }

    func didTapAddNodeButton() {
        wireframe.presentAddNodeFlow(with: interactor.chain, moduleOutput: self, from: view)
    }
}

extension NodeSelectionPresenter: NodeSelectionInteractorOutputProtocol {
    func didReceive(chain: ChainModel) {
        let viewModel = viewModelFactory.buildViewModel(from: chain)
        view?.didReceive(state: .loaded(viewModel: viewModel))
    }
}

extension NodeSelectionPresenter: Localizable {
    func applyLocalization() {
        view?.didReceive(locale: selectedLocale)
    }
}

extension NodeSelectionPresenter: AddCustomNodeModuleOutput {}
