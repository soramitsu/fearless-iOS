import Foundation
import SoraFoundation

final class SelectNetworkPresenter {
    // MARK: Private properties

    private weak var view: SelectNetworkViewInput?
    private let router: SelectNetworkRouterInput
    private let interactor: SelectNetworkInteractorInput

    private let selectedChainId: ChainModel.Id?
    private let viewModelFactory: SelectNetworkViewModelFactoryProtocol
    private let selectedMetaAccount: MetaAccountModel
    private let includingAllNetworks: Bool
    private let searchTextsViewModel: TextSearchViewModel?

    private var viewModels: [SelectableIconDetailsListViewModel] = []
    private var fullViewModels: [SelectableIconDetailsListViewModel] = []
    private var networkItems: [SelectNetworkItem] = []
    private var selectedNetwork: ChainModel?

    // MARK: - Constructors

    init(
        viewModelFactory: SelectNetworkViewModelFactoryProtocol,
        selectedMetaAccount: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        includingAllNetworks: Bool,
        searchTextsViewModel: TextSearchViewModel?,
        interactor: SelectNetworkInteractorInput,
        router: SelectNetworkRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.viewModelFactory = viewModelFactory
        self.selectedMetaAccount = selectedMetaAccount
        self.selectedChainId = selectedChainId
        self.includingAllNetworks = includingAllNetworks
        self.searchTextsViewModel = searchTextsViewModel
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        viewModels = viewModelFactory.buildViewModel(
            items: networkItems,
            selectedMetaAccount: selectedMetaAccount,
            selectedChainId: selectedChainId,
            locale: selectedLocale
        )
        fullViewModels = viewModels

        view?.didReload()
    }
}

// MARK: - SelectNetworkViewOutput

extension SelectNetworkPresenter: SelectNetworkViewOutput {
    var numberOfItems: Int {
        viewModels.count
    }

    func item(at index: Int) -> SelectableViewModelProtocol {
        viewModels[index]
    }

    func selectItem(at index: Int) {
        guard let view = view else { return }
        guard
            let selectedViewModel = viewModels[safe: index],
            let selectedNetworkItem = networkItems.first(where: { networkItem in
                guard case let .chain(chain) = networkItem else {
                    return false
                }
                return chain.chainId == selectedViewModel.identifier
            })
        else {
            router.complete(on: view, selecting: nil)
            return
        }
        selectedNetwork = selectedNetworkItem.chain
        router.complete(on: view, selecting: selectedNetworkItem.chain)
    }

    func searchItem(with text: String?) {
        guard let text = text, text.isNotEmpty else {
            viewModels = fullViewModels
            view?.didReload()
            return
        }

        viewModels = viewModels.filter { $0.title.lowercased().contains(text.lowercased()) }
        view?.didReload()
    }

    func didLoad(view: SelectNetworkViewInput) {
        self.view = view
        interactor.setup(with: self)
        view.bind(viewModel: searchTextsViewModel)
    }

    func willDisappear() {
        guard let view = view else { return }
        router.complete(on: view, selecting: selectedNetwork)
    }
}

// MARK: - SelectNetworkInteractorOutput

extension SelectNetworkPresenter: SelectNetworkInteractorOutput {
    func didReceiveChains(result: Result<[ChainModel], Error>) {
        switch result {
        case let .success(chains):
            var items: [SelectNetworkItem] = []
            if includingAllNetworks {
                items.append(.allNetworks)
            }
            chains.forEach { items.append(.chain($0)) }
            networkItems = items
            provideViewModel()
        case let .failure(error):
            router.present(error: error, from: view, locale: selectedLocale)
        }
    }
}

// MARK: - Localizable

extension SelectNetworkPresenter: Localizable {
    func applyLocalization() {
        provideViewModel()
    }
}

extension SelectNetworkPresenter: SelectNetworkModuleInput {}
