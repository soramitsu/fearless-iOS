import Foundation
import SoraFoundation
import SoraKeystore
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
    private let userDefaultsStorage: SettingsManagerProtocol
    private let stateHolder: MainNftContainerStateHolder

    // MARK: - Constructors

    init(
        interactor: MainNftContainerInteractorInput,
        router: MainNftContainerRouterInput,
        localizationManager: LocalizationManagerProtocol,
        viewModelFactory: NftListViewModelFactoryProtocol,
        wallet: MetaAccountModel,
        eventCenter: EventCenterProtocol,
        userDefaultsStorage: SettingsManagerProtocol,
        stateHolder: MainNftContainerStateHolder
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.wallet = wallet
        self.eventCenter = eventCenter
        self.userDefaultsStorage = userDefaultsStorage
        self.stateHolder = stateHolder
        self.localizationManager = localizationManager

        eventCenter.add(observer: self)
    }

    // MARK: - Private methods

    private func setupAppearance() {
        let showNftsLikeCollection: Bool = userDefaultsStorage.bool(
            for: NftAppearanceKeys.showNftsLikeCollection.rawValue
        ) ?? true
        view?.didReceive(appearance: showNftsLikeCollection ? .collection : .table)
    }
}

// MARK: - MainNftContainerViewOutput

extension MainNftContainerPresenter: MainNftContainerViewOutput {
    func didLoad(view: MainNftContainerViewInput) {
        self.view = view
        interactor.setup(with: self)
        interactor.fetchData()
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
        userDefaultsStorage.set(
            value: true,
            for: NftAppearanceKeys.showNftsLikeCollection.rawValue
        )
    }

    func didTapTableButton() {
        userDefaultsStorage.set(
            value: false,
            for: NftAppearanceKeys.showNftsLikeCollection.rawValue
        )
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
    func didSelect(chain: ChainModel?) {
        interactor.didSelect(chain: chain)
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
        DispatchQueue.main.async { [weak self] in
            self?.view?.didReceive(viewModels: nil)
        }
        interactor.applyFilters(filters)
    }
}
