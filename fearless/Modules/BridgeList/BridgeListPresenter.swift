import Foundation
import SoraFoundation
import SSFModels

protocol BridgeListViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: BridgeListViewModel)
}

protocol BridgeListInteractorInput: AnyObject {
    func setup(with output: BridgeListInteractorOutput)
    func getCrossChainQuotes(sort: UInt8) async throws -> [OKXCrossChainQuote]?
}

final class BridgeListPresenter {
    weak var moduleOutput: BridgeListModuleOutput?

    // MARK: Private properties

    private weak var view: BridgeListViewInput?
    private let router: BridgeListRouterInput
    private let interactor: BridgeListInteractorInput
    private let viewModelFactory: BridgeListViewModelFactory
    private let sourceChainAsset: ChainAsset
    private let destinationChainAsset: ChainAsset

    private var selectedSort: UInt8 = 0

    private var quotes: [OKXCrossChainQuote]?

    // MARK: - Constructors

    init(
        interactor: BridgeListInteractorInput,
        router: BridgeListRouterInput,
        localizationManager: LocalizationManagerProtocol,
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        viewModelFactory: BridgeListViewModelFactory,
        selectedSort: UInt8
    ) {
        self.interactor = interactor
        self.router = router
        self.sourceChainAsset = sourceChainAsset
        self.destinationChainAsset = destinationChainAsset
        self.viewModelFactory = viewModelFactory
        self.selectedSort = selectedSort

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func fetchQuotes() {
        Task {
            do {
                let quotes1 = try await interactor.getCrossChainQuotes(sort: 0)
                let quotes2 = try await interactor.getCrossChainQuotes(sort: 1)
                let quotes3 = try await interactor.getCrossChainQuotes(sort: 2)

                self.quotes = [quotes1.or([]), quotes2.or([]), quotes3.or([])].reduce([], +).uniqued(on: { quote in
                    quote.routerList.first?.router.bridgeId
                })

                await MainActor.run {
                    provideViewModel()
                }
            } catch {
                print("Fetch quotes error: ", error)
            }
        }
    }

    private func provideViewModel() {
        let viewModel = viewModelFactory.buildCrossChainViewModel(
            crossChainQuotes: quotes,
            locale: selectedLocale,
            destinationChainAsset: destinationChainAsset,
            selectedSort: selectedSort
        )

        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - BridgeListViewOutput

extension BridgeListPresenter: BridgeListViewOutput {
    func didLoad(view: BridgeListViewInput) {
        self.view = view
        interactor.setup(with: self)
        fetchQuotes()
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapSaveButton() {
        moduleOutput?.didUpdateSelectedSort(selectedSort)
        router.dismiss(view: view)
    }

    func didSelectSort(_ sort: UInt8) {
        selectedSort = sort
        provideViewModel()
    }
}

// MARK: - BridgeListInteractorOutput

extension BridgeListPresenter: BridgeListInteractorOutput {}

// MARK: - Localizable

extension BridgeListPresenter: Localizable {
    func applyLocalization() {}
}

extension BridgeListPresenter: BridgeListModuleInput {}
