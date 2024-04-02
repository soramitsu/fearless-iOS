import Foundation
import SoraFoundation
import SSFModels

protocol NetworkManagmentViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: NetworkManagmentViewModel)
}

protocol NetworkManagmentInteractorInput: AnyObject {
    func setup(with output: NetworkManagmentInteractorOutput)
    func didTapFavoutite(with identifire: String)
    func didSelect(_ identifire: String)
}

final class NetworkManagmentPresenter {
    // MARK: Private properties

    private weak var view: NetworkManagmentViewInput?
    private weak var moduleOutput: NetworkManagmentModuleOutput?
    private let router: NetworkManagmentRouterInput
    private let interactor: NetworkManagmentInteractorInput

    private var wallet: MetaAccountModel
    private let viewModelFactory: NetworkManagmentViewModelFactory
    private let contextTag: Int?
    private let logger: LoggerProtocol

    private var chains: [ChainModel] = []
    private var searchText: String?
    private var initialFilter: NetworkManagmentFilter
    private var selectedFilter: NetworkManagmentFilter?
    private var currentViewModel: NetworkManagmentViewModel?

    // MARK: - Constructors

    init(
        wallet: MetaAccountModel,
        interactor: NetworkManagmentInteractorInput,
        router: NetworkManagmentRouterInput,
        moduleOutput: NetworkManagmentModuleOutput?,
        logger: LoggerProtocol,
        viewModelFactory: NetworkManagmentViewModelFactory,
        contextTag: Int?,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wallet = wallet
        self.interactor = interactor
        self.router = router
        self.moduleOutput = moduleOutput
        self.logger = logger
        self.viewModelFactory = viewModelFactory
        self.contextTag = contextTag

        initialFilter = NetworkManagmentFilter(identifier: wallet.networkManagmentFilter)

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func provideViewModel() {
        let viewModel = viewModelFactory.createViewModel(
            wallet: wallet,
            chains: chains,
            selectedFilter: selectedFilter,
            initialFilter: initialFilter,
            searchText: searchText,
            locale: selectedLocale
        )
        view?.didReceive(viewModel: viewModel)
        currentViewModel = viewModel
    }
}

// MARK: - NetworkManagmentViewOutput

extension NetworkManagmentPresenter: NetworkManagmentViewOutput {
    func didTappedFavouriteButton(at indexPath: IndexPath?) {
        guard
            let indexPath = indexPath,
            let viewModel = currentViewModel,
            let selectedViewModel = viewModel.cells[safe: indexPath.row]
        else {
            logger.error("Did select row guard return")
            return
        }
        interactor.didTapFavoutite(with: selectedViewModel.networkSelectType.identifier)
    }

    func searchTextDidChanged(_ text: String?) {
        searchText = text
        provideViewModel()
    }

    func didSelectRow(at indexPath: IndexPath) {
        guard
            let viewModel = currentViewModel,
            let selectedViewModel = viewModel.cells[safe: indexPath.row]
        else {
            logger.error("Did select row guard return")
            return
        }
        moduleOutput?.did(select: selectedViewModel.networkSelectType, contextTag: contextTag)
        interactor.didSelect(selectedViewModel.networkSelectType.identifier)
        router.dismiss(view: view)
    }

    func didSelectAllFilter() {
        selectedFilter = .all
        provideViewModel()
    }

    func didSelectPopularFilter() {
        selectedFilter = .popular
        provideViewModel()
    }

    func didSelectFavouriteFilter() {
        selectedFilter = .favourite
        provideViewModel()
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didLoad(view: NetworkManagmentViewInput) {
        self.view = view
        interactor.setup(with: self)
    }
}

// MARK: - NetworkManagmentInteractorOutput

extension NetworkManagmentPresenter: NetworkManagmentInteractorOutput {
    func didReceiveUpdated(wallet: MetaAccountModel) {
        self.wallet = wallet
        provideViewModel()
    }

    func didReceiveChains(result: Result<[SSFModels.ChainModel], Error>) {
        switch result {
        case let .success(chains):
            self.chains = chains
            provideViewModel()
        case let .failure(error):
            logger.customError(error)
        }
    }
}

// MARK: - Localizable

extension NetworkManagmentPresenter: Localizable {
    func applyLocalization() {}
}

extension NetworkManagmentPresenter: NetworkManagmentModuleInput {}
