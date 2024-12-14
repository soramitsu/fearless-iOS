import Foundation
import SoraFoundation
import SSFModels

protocol DexListViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: DexListViewModel)
}

protocol DexListInteractorInput: AnyObject {
    func setup(with output: DexListInteractorOutput)
    func getCrossChainQuotes(sort: UInt8) async throws -> [OKXCrossChainQuote]?
    func getSameChainQuotes() async throws -> [OKXDexQuote]?
    func getLiquiditySources() async throws -> [OKXLiquiditySource]?
}

final class DexListPresenter {
    weak var moduleOutput: DexListModuleOutput?

    // MARK: Private properties

    private weak var view: DexListViewInput?
    private let router: DexListRouterInput
    private let interactor: DexListInteractorInput
    private let viewModelFactory: DexListViewModelFactory
    private let sourceChainAsset: ChainAsset
    private let destinationChainAsset: ChainAsset

    private var selectedDexIds: [String]?

    private var liquiditySources: [OKXLiquiditySource]?
    private var swapQuotes: [OKXDexQuote]?

    // MARK: - Constructors

    init(
        interactor: DexListInteractorInput,
        router: DexListRouterInput,
        localizationManager: LocalizationManagerProtocol,
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        viewModelFactory: DexListViewModelFactory,
        selectedDexIds: [String]?
    ) {
        self.interactor = interactor
        self.router = router
        self.sourceChainAsset = sourceChainAsset
        self.destinationChainAsset = destinationChainAsset
        self.viewModelFactory = viewModelFactory
        self.selectedDexIds = selectedDexIds

        self.localizationManager = localizationManager
    }

    // MARK: - Private methods

    private func fetchQuotes() {
        let isCrossChain = sourceChainAsset.chain.chainId != destinationChainAsset.chain.chainId

        Task {
            do {
                if isCrossChain {
                    let quotes = try await interactor.getCrossChainQuotes(sort: 0)
                    let viewModel = viewModelFactory.buildCrossChainViewModel(crossChainQuotes: quotes, locale: selectedLocale, destinationChainAsset: destinationChainAsset)

                    await MainActor.run {
                        view?.didReceive(viewModel: viewModel)
                    }
                } else {
                    let quotes = try await interactor.getSameChainQuotes()
                    let liquiditySources = try await interactor.getLiquiditySources()

                    if selectedDexIds == nil {
                        if
                            let quotesNames = quotes?.compactMap({ $0.dexName.lowercased() }),
                            let filteredSources = liquiditySources?.filter({ quotesNames.contains($0.name.lowercased()) == true }).compactMap({ $0.id })
                        {
                            self.selectedDexIds = filteredSources
                        }
                    }

                    let viewModel = viewModelFactory.buildSwapViewModel(
                        quotes: quotes,
                        liquiditySources: liquiditySources,
                        locale: selectedLocale,
                        chainAsset: sourceChainAsset,
                        selectedDexIds: selectedDexIds
                    )

                    self.liquiditySources = liquiditySources
                    self.swapQuotes = quotes

                    await MainActor.run {
                        view?.didReceive(viewModel: viewModel)
                    }
                }
            } catch {
                print("Failed to fetch quotes: ", error)
            }
        }
    }

    private func updateSwapViewModel() {
        let viewModel = viewModelFactory.buildSwapViewModel(
            quotes: swapQuotes,
            liquiditySources: liquiditySources,
            locale: selectedLocale,
            chainAsset: sourceChainAsset,
            selectedDexIds: selectedDexIds
        )

        view?.didReceive(viewModel: viewModel)
    }
}

// MARK: - DexListViewOutput

extension DexListPresenter: DexListViewOutput {
    func didLoad(view: DexListViewInput) {
        self.view = view
        interactor.setup(with: self)
        fetchQuotes()
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapSaveButton() {
        moduleOutput?.didUpdateSelectedDexIds(selectedDexIds)
        router.dismiss(view: view)
    }

    func didSelectLiquiditySource(with id: String) {
        var selectedDexIds = self.selectedDexIds ?? []

        if selectedDexIds.contains(id) {
            selectedDexIds = selectedDexIds.filter { $0 != id }
        } else {
            selectedDexIds.append(id)
        }

        self.selectedDexIds = selectedDexIds

        updateSwapViewModel()
    }
}

// MARK: - DexListInteractorOutput

extension DexListPresenter: DexListInteractorOutput {}

// MARK: - Localizable

extension DexListPresenter: Localizable {
    func applyLocalization() {}
}

extension DexListPresenter: DexListModuleInput {}
