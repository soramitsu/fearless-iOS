import SoraFoundation
import SoraKeystore
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class CovHNftMainViewSpy: CovHNftHostController, MainNftContainerViewInput {
    private(set) var viewModels: [[NftNetworkSectionModel]?] = []
    private(set) var appearances: [NftCollectionAppearance] = []

    func didReceive(viewModels: [NftNetworkSectionModel]?) {
        self.viewModels.append(viewModels)
    }

    func didReceive(appearance: NftCollectionAppearance) {
        appearances.append(appearance)
    }
}

final class CovHNftMainInteractorSpy: MainNftContainerInteractorInput {
    var showNftsLikeCollection = true
    private(set) weak var output: MainNftContainerInteractorOutput?
    private(set) var initialSetups = 0
    private(set) var fetches = 0
    private(set) var selectedChains: [[ChainModel]?] = []
    private(set) var appliedFilters: [[FilterSet]] = []

    func initialSetup() { initialSetups += 1 }
    func setup(with output: MainNftContainerInteractorOutput) { self.output = output }
    func fetchData() { fetches += 1 }
    func didSelect(chains: [ChainModel]?) { selectedChains.append(chains) }
    func applyFilters(_ filters: [FilterSet]) { appliedFilters.append(filters) }
}

final class CovHNftMainRouterSpy: MainNftContainerRouterInput {
    private(set) var shownCollections: [(NFTCollection, String)] = []
    private(set) var filterPresentations: [[FilterSet]] = []
    private(set) var messages: [(String?, String)] = []

    func showCollection(_ collection: NFTCollection, wallet _: MetaAccountModel, address: String, from _: ControllerBackedProtocol?) {
        shownCollections.append((collection, address))
    }

    func presentFilters(with filters: [FilterSet], from _: ControllerBackedProtocol?, moduleOutput _: NftFiltersModuleOutput?) {
        filterPresentations.append(filters)
    }

    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool { true }

    func present(message: String?, title: String, closeAction _: String?, from _: ControllerBackedProtocol?, actions _: [SheetAlertPresentableAction]) {
        messages.append((message, title))
    }
}

final class CovHNftMainOutputSpy: MainNftContainerInteractorOutput {
    private let lock = NSLock()
    private var storedCollections: [[NFTCollection]] = []

    var collections: [[NFTCollection]] { lock.lock(); defer { lock.unlock() }; return storedCollections }

    func didReceive(collections: [NFTCollection]) {
        lock.lock()
        storedCollections.append(collections)
        lock.unlock()
    }

    func didReceive(alert _: String) {}
}

final class CovHNftMainContainerPresenterTests: XCTestCase {
    private struct Context {
        let view = CovHNftMainViewSpy()
        let interactor = CovHNftMainInteractorSpy()
        let router = CovHNftMainRouterSpy()
        let events = CovHNftEventCenterSpy()
        let wallet = CovHNftFixtures.wallet()
        let stateHolder = MainNftContainerStateHolder(
            filters: [FilterSet(title: "", items: NftCollectionFilter.defaultFilters())]
        )
        let presenter: MainNftContainerPresenter

        init() {
            presenter = MainNftContainerPresenter(
                interactor: interactor,
                router: router,
                localizationManager: LocalizationManager.shared,
                viewModelFactory: NftListViewModelFactory(),
                wallet: wallet,
                eventCenter: events,
                stateHolder: stateHolder
            )
        }
    }

    func testLoadAppearanceAndLayoutButtons() {
        let context = Context()
        XCTAssertTrue(context.events.observers.first === context.presenter)
        context.presenter.didLoad(view: context.view)
        XCTAssertTrue(context.interactor.output === context.presenter)

        context.presenter.viewAppeared()
        context.presenter.didTapTableButton()
        XCTAssertFalse(context.interactor.showNftsLikeCollection)
        context.presenter.viewAppeared()
        context.presenter.didTapCollectionButton()
        XCTAssertTrue(context.interactor.showNftsLikeCollection)

        XCTAssertEqual(context.interactor.initialSetups, 2)
        XCTAssertEqual(context.view.appearances, [.collection, .table])

        context.presenter.didPullToRefresh()
        XCTAssertEqual(context.interactor.fetches, 1)
        context.presenter.applyLocalization()
        XCTAssertEqual(context.view.viewModels.count, 0)
    }

    func testSelectingCollectionRoutesWithWalletAddress() {
        let context = Context()
        context.presenter.didLoad(view: context.view)
        let chain = CovHNftFixtures.chain()
        let collection = CovHNftFixtures.collection(chain: chain)
        context.presenter.didSelect(collection: collection)

        XCTAssertEqual(context.router.shownCollections.count, 1)
        XCTAssertEqual(context.router.shownCollections.first?.0, collection)
        XCTAssertEqual(context.router.shownCollections.first?.1, CovHNftFixtures.address(of: context.wallet, on: chain))
    }

    func testSelectingCollectionWithoutAccountDoesNothing() {
        let context = Context()
        context.presenter.didLoad(view: context.view)
        context.presenter.processSelectedAccountChanged(event: SelectedAccountChanged(account: CovHNftFixtures.walletWithoutAccounts()))
        context.presenter.didSelect(collection: CovHNftFixtures.collection(chain: CovHNftFixtures.chain()))

        XCTAssertTrue(context.router.shownCollections.isEmpty)
        XCTAssertEqual(context.interactor.fetches, 1)
        CovHNftWait.until { context.view.viewModels.count == 1 }
        XCTAssertEqual(context.view.viewModels.count, 1)
        XCTAssertNil(context.view.viewModels.first ?? nil)
    }

    func testCollectionsAreGroupedIntoSections() {
        let context = Context()
        context.presenter.didLoad(view: context.view)
        let chain = CovHNftFixtures.chain()
        let nft = CovHNftFixtures.nft(chain: chain)
        context.presenter.didReceive(collections: [CovHNftFixtures.collection(chain: chain, nfts: [nft])])

        CovHNftWait.until { !context.view.viewModels.isEmpty }
        let sections = context.view.viewModels.first ?? nil
        XCTAssertEqual(sections?.count, 1)
        XCTAssertEqual(sections?.first?.chainId, chain.chainId)
        XCTAssertEqual(sections?.first?.items.first?.collection.name, "CovH Collection")
        XCTAssertTrue(sections?.first?.networkTitle.hasPrefix(chain.name) == true)
    }

    func testAlertIsPresentedAsDebugMessage() {
        let context = Context()
        context.presenter.didLoad(view: context.view)
        context.presenter.didReceive(alert: "covh-alert")

        CovHNftWait.until { !context.router.messages.isEmpty }
        XCTAssertEqual(context.router.messages.first?.0, "covh-alert")
        XCTAssertEqual(context.router.messages.first?.1, "debug message")
    }

    func testChainSelectionOnlyReloadsWhenChainsChange() {
        let context = Context()
        context.presenter.didLoad(view: context.view)
        let chains = [CovHNftFixtures.chain()]

        context.presenter.didSelect(chains: nil)
        XCTAssertTrue(context.interactor.selectedChains.isEmpty)

        context.presenter.didSelect(chains: chains)
        XCTAssertEqual(context.interactor.selectedChains.count, 1)
        XCTAssertEqual(context.interactor.selectedChains.first??.first?.chainId, chains.first?.chainId)
        CovHNftWait.until { context.view.viewModels.count == 1 }
        XCTAssertEqual(context.view.viewModels.count, 1)
    }

    func testFiltersApplyOnlyWhenSelectionChanges() {
        let context = Context()
        context.presenter.didLoad(view: context.view)

        context.presenter.didTapFilterButton()
        XCTAssertEqual(context.router.filterPresentations.count, 1)
        XCTAssertEqual(context.router.filterPresentations.first?.first?.items.count, 2)

        context.presenter.didFinishWithFilters(filters: [FilterSet(title: "", items: NftCollectionFilter.defaultFilters())])
        XCTAssertTrue(context.interactor.appliedFilters.isEmpty)

        let changed = [FilterSet(title: "", items: [
            NftCollectionFilter(type: .spam, selected: true),
            NftCollectionFilter(type: .airdrop, selected: true)
        ])]
        context.presenter.didFinishWithFilters(filters: changed)
        XCTAssertEqual(context.interactor.appliedFilters.count, 1)
        CovHNftWait.until { context.view.viewModels.count == 1 }
        XCTAssertEqual(context.view.viewModels.count, 1)
    }
}

final class CovHNftMainContainerInteractorTests: XCTestCase {
    private func makeInteractor(
        service: CovHNftFetchingStub,
        settings: SettingsManagerProtocol = InMemorySettingsManager(),
        events: CovHNftEventCenterSpy = CovHNftEventCenterSpy(),
        stateHolder: MainNftContainerStateHolder = MainNftContainerStateHolder(
            filters: [FilterSet(title: "", items: NftCollectionFilter.defaultFilters())]
        )
    ) -> MainNftContainerInteractor {
        MainNftContainerInteractor(
            nftFetchingService: service,
            logger: Logger.shared,
            wallet: CovHNftFixtures.wallet(),
            eventCenter: events,
            stateHolder: stateHolder,
            userDefaultsStorage: settings
        )
    }

    func testAppearancePreferenceIsStoredInSettings() {
        let settings = InMemorySettingsManager()
        let interactor = makeInteractor(service: CovHNftFetchingStub(), settings: settings)
        XCTAssertTrue(interactor.showNftsLikeCollection)
        interactor.showNftsLikeCollection = false
        XCTAssertFalse(interactor.showNftsLikeCollection)
        XCTAssertEqual(settings.bool(for: NftAppearanceKeys.showNftsLikeCollection.rawValue), false)
    }

    func testFetchWaitsForInitialSetupAndKeepsOnlyCollectionsWithOwnedNfts() {
        let service = CovHNftFetchingStub()
        let chain = CovHNftFixtures.chain()
        let owned = CovHNftFixtures.nft(chain: chain, contract: "0xowned")
        service.nfts = .success([owned])
        service.collections = .success([
            CovHNftFixtures.collection(chain: chain, address: "0xowned", name: "Owned"),
            CovHNftFixtures.collection(chain: chain, address: "0xempty", name: "Empty")
        ])
        let events = CovHNftEventCenterSpy()
        let interactor = makeInteractor(service: service, events: events)
        let output = CovHNftMainOutputSpy()
        interactor.setup(with: output)
        XCTAssertTrue(events.observers.first === interactor)

        interactor.fetchData()
        CovHNftWait.spin(0.2)
        XCTAssertTrue(service.excludes.isEmpty, "nothing loads before the screen appears")

        interactor.initialSetup()
        CovHNftWait.until { !output.collections.isEmpty }
        XCTAssertEqual(output.collections.first?.map(\.name), ["Owned"])
        XCTAssertEqual(output.collections.first?.first?.nfts, [owned])
        XCTAssertEqual(service.excludes.first, ["SPAM"])

        interactor.initialSetup()
        CovHNftWait.spin(0.2)
        XCTAssertEqual(service.excludes.count, 1, "a second appearance does not refetch")
    }

    func testFailureDeliversEmptyCollections() {
        let service = CovHNftFetchingStub()
        service.nfts = .failure(CovHNftError.failed)
        let interactor = makeInteractor(service: service)
        let output = CovHNftMainOutputSpy()
        interactor.setup(with: output)
        interactor.initialSetup()

        CovHNftWait.until { !output.collections.isEmpty }
        XCTAssertEqual(output.collections.count, 1)
        XCTAssertEqual(output.collections.first?.isEmpty, true)
    }

    func testChainsFiltersAndWalletChangesRefetch() {
        let service = CovHNftFetchingStub()
        let stateHolder = MainNftContainerStateHolder(filters: [])
        let interactor = makeInteractor(service: service, stateHolder: stateHolder)
        let output = CovHNftMainOutputSpy()
        interactor.setup(with: output)
        interactor.initialSetup()
        CovHNftWait.until { output.collections.count == 1 }

        let chains = [CovHNftFixtures.chain()]
        interactor.didSelect(chains: chains)
        XCTAssertEqual(stateHolder.selectedChains?.first?.chainId, chains.first?.chainId)
        CovHNftWait.until { output.collections.count == 2 }

        let filters = [FilterSet(title: nil, items: [NftCollectionFilter(type: .airdrop, selected: true)])]
        interactor.applyFilters(filters)
        XCTAssertEqual(stateHolder.filters.count, 1)
        CovHNftWait.until { output.collections.count == 3 }

        interactor.processSelectedAccountChanged(event: SelectedAccountChanged(account: CovHNftFixtures.wallet()))
        CovHNftWait.until { output.collections.count == 4 }

        XCTAssertEqual(output.collections.count, 4)
        XCTAssertEqual(service.excludes, [[], [], ["AIRDROPS"], ["AIRDROPS"]])
        XCTAssertEqual(service.chainRequests[1]?.first?.chainId, chains.first?.chainId)
    }
}

final class CovHNftMainContainerRoutingTests: XCTestCase {
    func testRouterPresentsCollectionInNavigationAndFiltersModally() throws {
        let host = CovHNftHostController()
        let navigation = CovHNftNavigationSpy(rootViewController: host)
        let router = MainNftContainerRouter()
        let chain = CovHNftFixtures.chain()
        let wallet = CovHNftFixtures.wallet()

        router.showCollection(CovHNftFixtures.collection(chain: chain), wallet: wallet, address: "covh-address", from: host)
        let presented = try XCTUnwrap(navigation.presented.first as? FearlessNavigationController)
        XCTAssertTrue(presented.viewControllers.first is NftCollectionViewController)

        router.presentFilters(with: [FilterSet(title: "", items: NftCollectionFilter.defaultFilters())], from: host, moduleOutput: nil)
        XCTAssertTrue(host.presented.first is NftFiltersViewController)

        router.presentFilters(with: [], from: nil, moduleOutput: nil)
        XCTAssertEqual(host.presented.count, 1)
    }

    func testAssemblyBuildsContainerModule() throws {
        let module = try XCTUnwrap(MainNftContainerAssembly.configureModule(wallet: CovHNftFixtures.wallet()))
        XCTAssertTrue(module.view.controller is MainNftContainerViewController)
        XCTAssertTrue(module.input is MainNftContainerPresenter)
    }

    func testListFactoryIdentitiesImagesAndOrdering() throws {
        let substrate = CovHNftFixtures.chain(name: "B chain")
        let ethereum = CovHNftFixtures.chain(name: "A chain", ethereum: true)
        let metadataNft = NFT(
            chain: substrate,
            tokenId: "2",
            title: nil,
            description: nil,
            smartContract: nil,
            metadata: NFTMetadata(name: "Meta", description: nil, image: "https://image.invalid/meta.png"),
            mediaThumbnail: nil,
            media: nil,
            tokenType: nil,
            collectionName: nil,
            collection: nil
        )
        let missing = CovHNftFixtures.collection(chain: substrate, address: nil, name: "Zed", nfts: [metadataNft])
        let upper = CovHNftFixtures.collection(chain: ethereum, address: "0xABC", name: "Upper", totalSupply: "5")

        let sections = NftListViewModelFactory().buildViewModel(from: [missing, upper], locale: Locale(identifier: "en"))

        XCTAssertEqual(sections.map(\.chainId), [ethereum.chainId, substrate.chainId])
        let upperItem = try XCTUnwrap(sections.first?.items.first)
        XCTAssertEqual(upperItem.identity.collectionId, "0xabc")
        XCTAssertEqual(upperItem.identity.ecosystem, "evm")
        XCTAssertEqual(upperItem.availableCount, 5)
        XCTAssertNil(upperItem.currentCount)
        XCTAssertNil(upperItem.imageViewModel)
        let missingItem = try XCTUnwrap(sections.last?.items.first)
        XCTAssertEqual(missingItem.identity.collectionId, "missing:2")
        XCTAssertNotNil(missingItem.imageViewModel)
        XCTAssertEqual(missingItem.currentCount, 1)
    }

    func testCollectionFiltersDefaultsResetAndEquality() {
        let defaults = NftCollectionFilter.defaultFilters()
        XCTAssertEqual(defaults.map(\.id), ["SPAM", "AIRDROPS"])
        XCTAssertEqual(defaults.map(\.selected), [true, false])
        XCTAssertFalse(defaults[0].title.isEmpty)
        XCTAssertFalse(defaults[1].title.isEmpty)

        var airdrop = defaults[1]
        airdrop.reset()
        XCTAssertTrue(airdrop.selected)
        XCTAssertNotEqual(airdrop, defaults[1])
        XCTAssertEqual(airdrop, NftCollectionFilter(type: .airdrop, selected: true))

        let holder = MainNftContainerStateHolder(filters: [])
        XCTAssertTrue(holder.filters.isEmpty)
        XCTAssertNil(holder.selectedChains)
    }
}
