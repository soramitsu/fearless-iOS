import Foundation
import SoraFoundation

final class NodeSelectionPresenter {
    weak var view: NodeSelectionViewProtocol?
    var interactor: NodeSelectionInteractorInputProtocol!

    private var viewModels: [SelectableSubtitleListViewModel] = []

    private var nodeItems: [NodeSelectionItem] = []

    private var selectedNodeItem: NodeSelectionItem?

    var logger: LoggerProtocol?

    private func updateView() {
        viewModels = nodeItems.map {
            let isSelected: Bool = $0 == selectedNodeItem
            let title: String = $0.title
            let subtitle: String = $0.address

            return SelectableSubtitleListViewModel(title: title,
                                                   subtitle: subtitle,
                                                   isSelected: isSelected)
        }

        view?.didReload()
    }

    private func updateSelectedNode() {
        for (index, viewModel) in viewModels.enumerated() {
            viewModel.isSelected = nodeItems[index] == selectedNodeItem
        }
    }
}

extension NodeSelectionPresenter: NodeSelectionPresenterProtocol {
    var numberOfItems: Int {
        return viewModels.count
    }

    func item(at index: Int) -> SelectableViewModelProtocol {
        return viewModels[index]
    }

    func selectItem(at index: Int) {
        interactor.select(nodeItem: nodeItems[index])
    }

    func setup() {
        interactor.load()
    }
}

extension NodeSelectionPresenter: NodeSelectionInteractorOutputProtocol {
    func didLoad(selectedNodeItem: NodeSelectionItem) {
        self.selectedNodeItem = selectedNodeItem
        updateSelectedNode()
    }

    func didLoad(nodeItems: [NodeSelectionItem]) {
        self.nodeItems = nodeItems
        updateView()
    }
}

extension NodeSelectionPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
