import Foundation
import SoraFoundation
import SSFModels

enum NftAppearanceKeys: String {
    case showNftsLikeCollection
}

final class MainNftContainerPresenter {
    // MARK: Private properties

    private weak var view: MainNftContainerViewInput?
    private let router: MainNftContainerRouterInput
    private let interactor: MainNftContainerInteractorInput
    private let viewModelFactory: NftListViewModelFactoryProtocol
    private var wallet: MetaAccountModel
    private let eventCenter: EventCenterProtocol
    private let stateHolder: MainNftContainerStateHolder

    // MARK: - Constructors

    init(
        interactor: MainNftContainerInteractorInput,
        router: MainNftContainerRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: NftListViewModelFactoryProtocol,
        wallet: MetaAccountModel,
        eventCenter: EventCenterProtocol,
        stateHolder: MainNftContainerStateHolder
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.wallet = wallet
        self.eventCenter = eventCenter
        self.stateHolder = stateHolder
        self.localizationManager = localizationManager

        eventCenter.add(observer: self)
    }

    // MARK: - Private methods

    private func setupAppearance() {
        view?.didReceive(appearance: interactor.showNftsLikeCollection ? .collection : .table)
    }
}

// MARK: - MainNftContainerViewOutput

extension MainNftContainerPresenter: MainNftContainerViewOutput {
    func didLoad(view: MainNftContainerViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func viewAppeared() {
        interactor.initialSetup()
        setupAppearance()
    }

    func didSelect(collection: NFTCollection) {
        guard let address = wallet.fetch(for: collection.chain.accountRequest())?.toAddress() else {
            return
        }

        router.showCollection(collection, wallet: wallet, address: address, from: view)
    }

    func didPullToRefresh() {
        interactor.fetchData()
    }

    func didTapFilterButton() {
        router.presentFilters(with: stateHolder.filters, from: view, moduleOutput: self)
    }

    func didTapCollectionButton() {
        interactor.showNftsLikeCollection = true
    }

    func didTapTableButton() {
        interactor.showNftsLikeCollection = false
    }
}

// MARK: - MainNftContainerInteractorOutput

extension MainNftContainerPresenter: MainNftContainerInteractorOutput {
    func didReceive(collections: [NFTCollection]) {
        let viewModels = viewModelFactory.buildViewModel(from: collections, locale: localizationManager?.selectedLocale ?? Locale.current)
        view?.didReceive(viewModels: viewModels)
    }
}

// MARK: - Localizable

extension MainNftContainerPresenter: Localizable {
    func applyLocalization() {}
}

extension MainNftContainerPresenter: MainNftContainerModuleInput {
    func didSelect(chains: [ChainModel]?) {
        if chains != stateHolder.selectedChains {
            DispatchQueue.main.async { [weak self] in
                self?.view?.didReceive(viewModels: nil)
            }
            interactor.didSelect(chains: chains)
        }
    }
}

extension MainNftContainerPresenter: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        wallet = event.account

        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceive(viewModels: nil)
        }
        interactor.fetchData()
    }
}

extension MainNftContainerPresenter: NftFiltersModuleOutput {
    func didFinishWithFilters(filters: [FilterSet]) {
        let selectedFiltersValues: [NftCollectionFilter] = filters.compactMap {
            $0.items as? [NftCollectionFilter]
        }.reduce([], +).filter { filter in
            filter.selected
        }
        let previousFiltersValues: [NftCollectionFilter] = stateHolder.filters.compactMap {
            $0.items as? [NftCollectionFilter]
        }.reduce([], +).filter { filter in
            filter.selected
        }
        if selectedFiltersValues != previousFiltersValues {
            DispatchQueue.main.async { [weak self] in
                self?.view?.didReceive(viewModels: nil)
            }
            interactor.applyFilters(filters)
        }
    }
}
