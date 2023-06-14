import Foundation
import SoraFoundation
import SSFModels

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

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildViewModel(
            from: interactor.chain,
            locale: selectedLocale,
            cellsDelegate: self
        )
        view?.didReceive(state: .loaded(viewModel: viewModel))
    }
}

extension NodeSelectionPresenter: NodeSelectionPresenterProtocol {
    func didChangeValueForAutomaticNodeSwitch(isOn: Bool) {
        interactor.setAutomaticSwitchNodes(isOn)
    }

    func setup() {
        interactor.setup()
        view?.didReceive(locale: selectedLocale)
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
    func didReceive(chain _: ChainModel) {
        provideViewModel()
    }
}

extension NodeSelectionPresenter: Localizable {
    func applyLocalization() {
        provideViewModel()

        view?.didReceive(locale: selectedLocale)
    }
}

extension NodeSelectionPresenter: AddCustomNodeModuleOutput {
    func didChangedNodesList() {
//        provideViewModel()
    }
}

extension NodeSelectionPresenter: NodeSelectionTableCellViewModelDelegate {
    func deleteNode(_ node: ChainNodeModel) {
        let viewModel = viewModelFactory.buildDeleteNodeAlertViewModel(
            node: node,
            locale: selectedLocale
        ) { [weak self] in
            self?.interactor.deleteNode(node)
        }

        wireframe.present(viewModel: viewModel, from: view)
    }

    func showCustomNodeInfo(_ node: ChainNodeModel) {
        showNodeInfo(node, mode: .all)
    }

    func showDefaultNodeInfo(_ node: ChainNodeModel) {
        showNodeInfo(node, mode: .none)
    }

    func showNodeInfo(_ node: ChainNodeModel, mode: NetworkInfoMode) {
        wireframe.presentNodeInfo(
            chain: interactor.chain,
            node: node,
            mode: mode,
            from: view
        )
    }
}
