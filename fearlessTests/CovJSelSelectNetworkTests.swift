import XCTest
import UIKit
import SoraFoundation
import SSFModels
import RobinHood
@testable import fearless

final class CovJSelSelectNetworkInteractorSpy: SelectNetworkInteractorInput {
    private(set) var setupCount = 0

    func setup(with _: SelectNetworkInteractorOutput) {
        setupCount += 1
    }
}

final class CovJSelSelectNetworkRouterSpy: CovJSheetSpy, SelectNetworkRouterInput {
    private(set) var completions: [(chain: ChainModel?, tag: Int?)] = []

    func complete(on _: SelectNetworkViewInput, selecting chain: ChainModel?, contextTag: Int?) {
        completions.append((chain, contextTag))
    }
}

final class CovJSelSelectNetworkOutputSpy: SelectNetworkInteractorOutput {
    private(set) var results: [Result<[ChainModel], Error>] = []

    func didReceiveChains(result: Result<[ChainModel], Error>) {
        results.append(result)
    }
}

final class CovJSelSelectNetworkDelegateSpy: SelectNetworkDelegate {
    private(set) var completions: [(chain: ChainModel?, tag: Int?)] = []

    func chainSelection(view _: SelectNetworkViewInput, didCompleteWith chain: ChainModel?, contextTag: Int?) {
        completions.append((chain, contextTag))
    }
}

final class CovJSelSelectNetworkListSpy: SelectNetworkViewOutput {
    var items: [SelectableViewModelProtocol]
    private(set) var loaded = 0
    private(set) var disappearances = 0
    private(set) var selected: [Int] = []
    private(set) var searches: [String?] = []

    init(items: [SelectableViewModelProtocol]) {
        self.items = items
    }

    var numberOfItems: Int { items.count }
    func item(at index: Int) -> SelectableViewModelProtocol { items[index] }
    func selectItem(at index: Int) { selected.append(index) }
    func searchItem(with text: String?) { searches.append(text) }
    func didLoad(view _: SelectNetworkViewInput) { loaded += 1 }
    func willDisappear() { disappearances += 1 }
}

final class CovJSelSelectNetworkTests: XCTestCase {
    private func titles(_ presenter: SelectNetworkPresenter) -> [String] {
        (0 ..< presenter.numberOfItems).compactMap { (presenter.item(at: $0) as? SelectableIconDetailsListViewModel)?.title }
    }

    func testFactoryAddsAllNetworksDropsAccountlessChainsAndMarksSelection() {
        let locale = CovJFixture.locale
        let wallet = CovJSelFixture.substrateWallet()
        let alpha = CovJSelFixture.chain(name: "Alpha", icon: UniversalWalletRegistry.bitcoinIconURL, assets: [])
        let ethereum = CovJSelFixture.chain(name: "Ethereum", options: [.ethereumBased], assets: [])
        let factory = SelectNetworkViewModelFactory()
        let items: [SelectNetworkItem] = [.allNetworks, .chain(alpha), .chain(ethereum)]

        let unselected = factory.buildViewModel(items: items, selectedMetaAccount: wallet, selectedChainId: nil, locale: locale)
        XCTAssertEqual(unselected.map(\.title), [R.string.localizable.chainSelectionAllNetworks(preferredLanguages: locale.rLanguages), "Alpha"])
        XCTAssertEqual(unselected.map(\.isSelected), [true, false])
        XCTAssertEqual(unselected.map(\.identifier), [nil, alpha.chainId])
        XCTAssertNil(unselected[0].icon)
        XCTAssertNotNil(unselected[1].icon)
        XCTAssertNil(unselected[1].subtitle)

        let selected = factory.buildViewModel(items: items, selectedMetaAccount: wallet, selectedChainId: alpha.chainId, locale: locale)
        XCTAssertEqual(selected.map(\.isSelected), [false, true])
        XCTAssertNil(SelectNetworkItem.allNetworks.chain)
        XCTAssertEqual(SelectNetworkItem.chain(alpha).chain?.chainId, alpha.chainId)
    }

    func testPresenterListsSearchesSelectsAndCompletesWithContext() throws {
        let manager = try CovJSelFixture.manager()
        let wallet = CovJSelFixture.substrateWallet()
        let alpha = CovJSelFixture.chain(name: "Alpha", assets: [])
        let beta = CovJSelFixture.chain(name: "Beta", assets: [])
        let ethereum = CovJSelFixture.chain(name: "Ethereum", options: [.ethereumBased], assets: [])
        let interactor = CovJSelSelectNetworkInteractorSpy()
        let router = CovJSelSelectNetworkRouterSpy()
        let view = CovJSelListViewSpy()
        let presenter = SelectNetworkPresenter(
            viewModelFactory: SelectNetworkViewModelFactory(),
            selectedMetaAccount: wallet,
            selectedChainId: nil,
            includingAllNetworks: true,
            searchTextsViewModel: .searchNetworkPlaceholder,
            contextTag: 7,
            interactor: interactor,
            router: router,
            localizationManager: manager
        )
        presenter.selectItem(at: 0)
        presenter.willDisappear()
        XCTAssertTrue(router.completions.isEmpty, "nothing completes before the view loads")

        presenter.didLoad(view: view)
        XCTAssertEqual(interactor.setupCount, 1)
        XCTAssertEqual(view.boundSearch, [.searchNetworkPlaceholder])

        presenter.didReceiveChains(result: .success([alpha, beta, ethereum]))
        XCTAssertEqual(view.reloadCount, 1)
        let allTitle = R.string.localizable.chainSelectionAllNetworks(preferredLanguages: manager.selectedLocale.rLanguages)
        XCTAssertEqual(titles(presenter), [allTitle, "Alpha", "Beta"])

        presenter.searchItem(with: "BET")
        XCTAssertEqual(titles(presenter), ["Beta"])
        presenter.searchItem(with: "")
        XCTAssertEqual(titles(presenter), [allTitle, "Alpha", "Beta"])
        presenter.searchItem(with: "alp")
        presenter.searchItem(with: nil)
        XCTAssertEqual(presenter.numberOfItems, 3)
        XCTAssertEqual(view.reloadCount, 5)

        presenter.selectItem(at: 0)
        presenter.willDisappear()
        presenter.selectItem(at: 2)
        presenter.willDisappear()
        presenter.selectItem(at: 40)
        XCTAssertEqual(router.completions.count, 4, "closing after choosing a network does not complete twice")
        XCTAssertNil(router.completions[0].chain)
        XCTAssertNil(router.completions[1].chain)
        XCTAssertEqual(router.completions[2].chain?.chainId, beta.chainId)
        XCTAssertNil(router.completions[3].chain)
        XCTAssertTrue(router.completions.allSatisfy { $0.tag == 7 })

        presenter.applyLocalization()
        XCTAssertEqual(view.reloadCount, 6)
        presenter.didReceiveChains(result: .failure(CovJError("networks")))
        XCTAssertEqual(router.errors.compactMap { $0 as? CovJError }, [CovJError("networks")])
    }

    func testPresenterWithoutAllNetworksRowStartsFromTheFirstChain() throws {
        let wallet = CovJSelFixture.substrateWallet()
        let alpha = CovJSelFixture.chain(name: "Alpha", assets: [])
        let router = CovJSelSelectNetworkRouterSpy()
        let view = CovJSelListViewSpy()
        let presenter = SelectNetworkPresenter(
            viewModelFactory: SelectNetworkViewModelFactory(),
            selectedMetaAccount: wallet,
            selectedChainId: alpha.chainId,
            includingAllNetworks: false,
            searchTextsViewModel: nil,
            contextTag: nil,
            interactor: CovJSelSelectNetworkInteractorSpy(),
            router: router,
            localizationManager: try CovJSelFixture.manager()
        )
        presenter.didLoad(view: view)
        presenter.didReceiveChains(result: .success([alpha]))
        XCTAssertEqual(titles(presenter), ["Alpha"])
        XCTAssertTrue(presenter.item(at: 0).isSelected)
        presenter.selectItem(at: 0)
        XCTAssertEqual(router.completions.first?.chain?.chainId, alpha.chainId)
        XCTAssertNil(router.completions.first?.tag)
        XCTAssertEqual(view.boundSearch.count, 1)
        XCTAssertNil(view.boundSearch.first ?? nil)
    }

    func testInteractorDeliversPresetStoredAndFailedChains() {
        let alpha = CovJSelFixture.chain(name: "Alpha", assets: [])
        let output = CovJSelSelectNetworkOutputSpy()
        let preset = SelectNetworkInteractor(
            repository: AnyDataProviderRepository(CovJMemoryRepository<ChainModel>()),
            operationQueue: OperationQueue(),
            chainModels: [alpha]
        )
        preset.setup(with: output)
        XCTAssertEqual(output.results.count, 1)

        let stored = SelectNetworkInteractor(
            output: output,
            repository: AnyDataProviderRepository(CovJMemoryRepository<ChainModel>([alpha])),
            operationQueue: OperationQueue(),
            chainModels: nil
        )
        stored.setup(with: output)
        XCTAssertTrue(CovJWait.until { output.results.count == 2 })
        if case let .success(chains) = output.results[1] {
            XCTAssertEqual(chains.map(\.chainId), [alpha.chainId])
        } else {
            XCTFail("expected the stored chains")
        }

        let failingRepository = CovJMemoryRepository<ChainModel>()
        failingRepository.failure = CovJError("store")
        let failing = SelectNetworkInteractor(
            repository: AnyDataProviderRepository(failingRepository),
            operationQueue: OperationQueue(),
            chainModels: nil
        )
        failing.setup(with: output)
        XCTAssertTrue(CovJWait.until { output.results.count == 3 })
        if case let .failure(error) = output.results[2] {
            XCTAssertEqual(error as? CovJError, CovJError("store"))
        } else {
            XCTFail("expected the repository failure")
        }
    }

    func testControllerRendersRowsAndForwardsSearchSelectionAndDisappearance() throws {
        let manager = try CovJSelFixture.manager()
        let presenter = CovJSelSelectNetworkListSpy(items: [
            SelectableIconDetailsListViewModel(title: "Alpha", subtitle: nil, icon: nil, isSelected: true, identifier: "a"),
            SelectableIconDetailsListViewModel(title: "Beta", subtitle: "B", icon: nil, isSelected: false, identifier: "b")
        ])
        let controller = SelectNetworkViewController(output: presenter, localizationManager: manager)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        controller.viewWillAppear(false)

        XCTAssertEqual(presenter.loaded, 1)
        let root = controller.rootView
        XCTAssertEqual(root.titleLabel.text, R.string.localizable.commonSelectNetwork(preferredLanguages: manager.selectedLocale.rLanguages))
        XCTAssertEqual(root.tableView.rowHeight, 50)
        XCTAssertEqual(root.tableView.separatorStyle, .none)
        XCTAssertNotNil(controller.keyboardHandler)
        XCTAssertNotNil(controller.target)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(10), 0)

        let table = root.tableView
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 2)
        let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 1, section: 0)) as? SelectionIconDetailsTableViewCell)
        XCTAssertEqual(cell.titleLabel.text, "Beta")
        controller.tableView(table, willDisplay: cell, forRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(cell.titleLabel.text, "Alpha")
        controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 0))
        XCTAssertEqual(presenter.selected, [1])

        root.searchTextField.onTextDidChanged?("be")
        XCTAssertEqual(presenter.searches, ["be"])
        controller.bind(viewModel: .searchNetworkPlaceholder)
        XCTAssertEqual(root.searchTextField.textField.placeholder,
                       TextSearchViewModel.searchNetworkPlaceholder.placeholder.value(for: root.locale))

        XCTAssertFalse(root.searchTextField.isHidden)
        controller.didReload()
        XCTAssertFalse(table.isHidden)
        XCTAssertTrue(root.emptyView.isHidden)
        presenter.items = []
        controller.didReload()
        XCTAssertEqual(table.numberOfRows(inSection: 0), 0)
        XCTAssertTrue(table.isHidden)
        XCTAssertFalse(root.emptyView.isHidden)
        controller.applyLocalization()
        XCTAssertEqual(root.locale, manager.selectedLocale)

        controller.viewWillDisappear(false)
        XCTAssertEqual(presenter.disappearances, 1)
        controller.viewDidDisappear(false)
        XCTAssertNil(controller.keyboardHandler)
    }

    func testAssembledModuleCompletesThroughRouterAndDelegate() throws {
        let wallet = CovJSelFixture.substrateWallet()
        let alpha = CovJSelFixture.chain(name: "Alpha", assets: [])
        let delegate = CovJSelSelectNetworkDelegateSpy()
        let module = try XCTUnwrap(SelectNetworkAssembly.configureModule(
            wallet: wallet,
            selectedChainId: nil,
            chainModels: [alpha],
            searchTextsViewModel: .searchNetworkPlaceholder,
            delegate: delegate,
            contextTag: 3
        ))
        let controller = try XCTUnwrap(module.view.controller as? SelectNetworkViewController)
        XCTAssertEqual(controller.modalPresentationStyle, .custom)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }

        let table = controller.rootView.tableView
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 2)
        controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 0))
        XCTAssertEqual(delegate.completions.count, 1)
        XCTAssertEqual(delegate.completions.first?.chain?.chainId, alpha.chainId)
        XCTAssertEqual(delegate.completions.first?.tag, 3)

        let router = SelectNetworkRouter(delegate: nil)
        router.complete(on: CovJSelListViewSpy(), selecting: nil, contextTag: nil)
        XCTAssertEqual(delegate.completions.count, 1)
    }

    func testSearchTextsDescribeNetworkAndAssetSearches() {
        let locale = CovJFixture.locale
        let languages = locale.rLanguages
        let network = TextSearchViewModel.searchNetworkPlaceholder
        let asset = TextSearchViewModel.searchAssetPlaceholder
        XCTAssertEqual(network.placeholder.value(for: locale), R.string.localizable.selectNetworkSearchPlaceholder(preferredLanguages: languages))
        XCTAssertEqual(asset.placeholder.value(for: locale), R.string.localizable.selectAssetSearchPlaceholder(preferredLanguages: languages))
        XCTAssertEqual(network.emptyViewTitle.value(for: locale), R.string.localizable.emptyViewTitle(preferredLanguages: languages))
        XCTAssertEqual(asset.emptyViewTitle.value(for: locale), network.emptyViewTitle.value(for: locale))
        XCTAssertEqual(network.emptyViewDescription.value(for: locale),
                       R.string.localizable.selectNetworkSearchEmptySubtitle(preferredLanguages: languages))
        XCTAssertEqual(asset.emptyViewDescription.value(for: locale),
                       R.string.localizable.selectAssetSearchEmptySubtitle(preferredLanguages: languages))
    }
}
