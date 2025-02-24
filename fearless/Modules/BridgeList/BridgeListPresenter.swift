import Foundation
import SoraFoundation
import SSFModels

protocol BridgeListViewInput: ControllerBackedProtocol, LoadableViewProtocol {
    func didReceive(viewModel: BridgeListViewModel)
}

protocol BridgeListInteractorInput: AnyObject {
    func setup(with output: BridgeListInteractorOutput)
    func getCrossChainQuotes(sort: UInt8) async throws -> [OKXCrossChainQuote]?
    func fetchAssets(for chain: ChainModel) async throws -> [ChainAsset]
}

final class BridgeListPresenter {
    var moduleOutput: BridgeListModuleOutput?

    // MARK: Private properties

    private weak var view: BridgeListViewInput?
    private let router: BridgeListRouterInput
    private let interactor: BridgeListInteractorInput
    private let viewModelFactory: BridgeListViewModelFactory
    private let sourceChainAsset: ChainAsset
    private let destinationChainAsset: ChainAsset

    private var selectedBridgeId: String?

    private var quotes: [OKXCrossChainQuote]?
    private var sourceChainAssets: [ChainAsset]?

    // MARK: - Constructors

    init(
        interactor: BridgeListInteractorInput,
        router: BridgeListRouterInput,
        localizationManager: LocalizationManagerProtocol,
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        viewModelFactory: BridgeListViewModelFactory,
        selectedBridgeId: String?
    ) {
        self.interactor = interactor
        self.router = router
        self.sourceChainAsset = sourceChainAsset
        self.destinationChainAsset = destinationChainAsset
        self.viewModelFactory = viewModelFactory
        self.selectedBridgeId = selectedBridgeId

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func fetchTokens() {
        Task {
            do {
                let assets = try await interactor.fetchAssets(for: sourceChainAsset.chain)
                self.sourceChainAssets = assets

                await MainActor.run {
                    provideViewModel()
                }
            } catch {
                print("Fetch quotes error: ", error)
            }
        }
    }

    private func fetchQuotes() {
        view?.didStartLoading()
        Task {
            do {
                async let quotes1 = try await interactor.getCrossChainQuotes(sort: 0)
                async let quotes2 = try await interactor.getCrossChainQuotes(sort: 1)
                async let quotes3 = try await interactor.getCrossChainQuotes(sort: 2)

                self.quotes = try await [quotes1.or([]), quotes2.or([]), quotes3.or([])].reduce([], +).uniqued(on: { quote in
                    quote.routerList.first?.router.bridgeId
                })

                await MainActor.run {
                    view?.didStopLoading()
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
            sourceChainAsset: sourceChainAsset,
            destinationChainAsset: destinationChainAsset,
            selectedBridgeId: selectedBridgeId,
            sourceChainAssets: sourceChainAssets
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
        fetchTokens()
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapSaveButton() {
        moduleOutput?.didSelectBridge(id: selectedBridgeId)
        router.dismiss(view: view)
    }
    
    func didSelectBridge(id: String?) {
        selectedBridgeId = id
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
