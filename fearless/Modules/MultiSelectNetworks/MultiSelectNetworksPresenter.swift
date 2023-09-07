import Foundation
import SoraFoundation
import SSFModels

protocol MultiSelectNetworksViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: MultiSelectNetworksViewModel)
}

protocol MultiSelectNetworksInteractorInput: AnyObject {
    func setup(with output: MultiSelectNetworksInteractorOutput)
}

final class MultiSelectNetworksPresenter {
    // MARK: Private properties

    private weak var view: MultiSelectNetworksViewInput?
    private weak var moduleOutput: MultiSelectNetworksModuleOutput?
    private let router: MultiSelectNetworksRouterInput
    private let interactor: MultiSelectNetworksInteractorInput

    private let canSelect: Bool
    private let dataSource: [ChainModel]
    private let selectedChains: [ChainModel.Id]?
    private let viewModelFactory: MultiSelectNetworksViewModelFactory

    private var viewModel: MultiSelectNetworksViewModel?
    private var searchText: String?

    // MARK: - Constructors

    init(
        canSelect: Bool,
        dataSource: [ChainModel],
        selectedChains: [ChainModel.Id]?,
        viewModelFactory: MultiSelectNetworksViewModelFactory,
        moduleOutput: MultiSelectNetworksModuleOutput?,
        interactor: MultiSelectNetworksInteractorInput,
        router: MultiSelectNetworksRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.canSelect = canSelect
        self.dataSource = dataSource
        self.selectedChains = selectedChains
        self.viewModelFactory = viewModelFactory
        self.moduleOutput = moduleOutput
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel(indexPath: IndexPath?) {
        var selectedChains = viewModel?.cells.filter { $0.isSelected }.map { $0.chainId } ?? self.selectedChains
        if viewModel != nil {
            selectedChains = viewModel?.cells.filter { $0.isSelected }.map { $0.chainId }
            if let indexPath = indexPath, let toggledViewModel = viewModel?.cells[safe: indexPath.row]?.toggle() {
                if toggledViewModel.isSelected {
                    selectedChains?.append(toggledViewModel.chainId)
                } else {
                    selectedChains?.removeAll(where: { $0 == toggledViewModel.chainId })
                }
            }
        }

        let viewModel = viewModelFactory.buildViewModel(
            dataSource: dataSource,
            selectedChains: selectedChains,
            searchText: searchText
        )
        view?.didReceive(viewModel: viewModel)

        if searchText != nil {
            let cells = self.viewModel?.cells ?? []
            let searchCells = viewModel.cells
            let newCells = Array(Set(cells + searchCells))
            let viewModel = self.viewModel?.replace(cells: newCells)
            self.viewModel = viewModel
        } else {
            self.viewModel = viewModel
        }
    }

    private func provideSelectAllViewModel() {
        guard canSelect else {
            return
        }
        let selectedChains = viewModel?.allIsSelected == false ? dataSource.map { $0.chainId } : []
        let viewModel = viewModelFactory.buildViewModel(
            dataSource: dataSource,
            selectedChains: selectedChains,
            searchText: nil
        )
        view?.didReceive(viewModel: viewModel)
        self.viewModel = viewModel
    }
}

// MARK: - MultiSelectNetworksViewOutput

extension MultiSelectNetworksPresenter: MultiSelectNetworksViewOutput {
    func selectAllDidTapped() {
        provideSelectAllViewModel()
    }

    func doneButtonDidTapped() {
        guard canSelect else {
            return
        }
        let selectedChains = viewModel?.cells.filter { $0.isSelected }.map { $0.chainId }
        moduleOutput?.selectedChain(ids: selectedChains)
        router.dismiss(view: view)
    }

    func searchTextDidChanged(_ text: String?) {
        searchText = text
        provideViewModel(indexPath: nil)
    }

    func didSelectRow(at indexPath: IndexPath) {
        guard canSelect else {
            return
        }
        provideViewModel(indexPath: indexPath)
    }

    func didLoad(view: MultiSelectNetworksViewInput) {
        self.view = view
        interactor.setup(with: self)
        provideViewModel(indexPath: nil)
    }
}

// MARK: - MultiSelectNetworksInteractorOutput

extension MultiSelectNetworksPresenter: MultiSelectNetworksInteractorOutput {}

// MARK: - Localizable

extension MultiSelectNetworksPresenter: Localizable {
    func applyLocalization() {}
}

extension MultiSelectNetworksPresenter: MultiSelectNetworksModuleInput {}
