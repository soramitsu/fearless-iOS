import XCTest
import UIKit
import SoraFoundation
import SSFModels
import RobinHood
@testable import fearless

final class CovJSelMultichainViewSpy: UIViewController, MultichainAssetSelectionViewInput {
    private(set) var received: [[ChainSelectionCollectionCellModel]] = []

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func didReceive(viewModels: [ChainSelectionCollectionCellModel]) {
        received.append(viewModels)
    }
}

final class CovJSelMultichainInteractorStub: MultichainAssetSelectionInteractorInput {
    var chains: Result<[ChainModel], Error>
    private(set) var setupCount = 0

    init(chains: Result<[ChainModel], Error>) {
        self.chains = chains
    }

    func setup(with _: MultichainAssetSelectionInteractorOutput) {
        setupCount += 1
    }

    func fetchChains() async throws -> [ChainModel] {
        try chains.get()
    }

    func fetchAssets(for chain: ChainModel) async throws -> [ChainAsset] {
        chain.chainAssets
    }
}

final class CovJSelMultichainOutputSpy: MultichainAssetSelectionViewOutput {
    private(set) var loaded = 0
    private(set) var selected: [ChainModel] = []
    private(set) var closes = 0

    func didLoad(view _: MultichainAssetSelectionViewInput) { loaded += 1 }
    func didSelect(chain: ChainModel) { selected.append(chain) }
    func didTapCloseButton() { closes += 1 }
}

struct CovJSelChainFetchingStub: MultichainChainFetching {
    let chains: [ChainModel]

    func fetchChains() async throws -> [ChainModel] {
        chains
    }
}

final class CovJSelMultichainAssetSelectionTests: XCTestCase {
    private func rgba(_ color: UIColor?) -> [CGFloat] {
        guard let color else { return [] }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha]
    }

    @MainActor
    func testPresenterSelectsFirstChainSwitchesChainsAndForwardsResults() throws {
        let alpha = CovJSelFixture.chain(name: "Alpha", assets: [CovJSelFixture.asset("a")])
        let beta = CovJSelFixture.chain(name: "Beta", icon: UniversalWalletRegistry.bitcoinIconURL, assets: [CovJSelFixture.asset("b")])
        let interactor = CovJSelMultichainInteractorStub(chains: .success([alpha, beta]))
        let router = CovJSelDismissSpy()
        let output = CovJSelSelectAssetOutputSpy()
        let input = CovJSelSelectAssetInputSpy()
        let view = CovJSelMultichainViewSpy()
        let presenter = MultichainAssetSelectionPresenter(
            interactor: interactor,
            router: router,
            localizationManager: try CovJSelFixture.manager(),
            viewModelFactory: MultichainAssetSelectionViewModelFactoryImpl(),
            logger: Logger.shared,
            selectAssetModuleOutput: output
        )
        presenter.selectAssetModuleInput = input

        presenter.didLoad(view: view)
        XCTAssertEqual(interactor.setupCount, 1)
        XCTAssertTrue(CovJWait.until { view.received.count == 1 })
        XCTAssertEqual(view.received[0].map(\.chain.chainId), [alpha.chainId, beta.chainId])
        XCTAssertEqual(view.received[0].map(\.selected), [true, false])
        XCTAssertNil(view.received[0][0].imageViewModel)
        XCTAssertNotNil(view.received[0][1].imageViewModel)
        XCTAssertEqual(input.updates.first?.map(\.asset.id), ["a"])

        presenter.didSelect(chain: beta)
        XCTAssertEqual(input.updates.last?.map(\.asset.id), ["b"])
        XCTAssertTrue(CovJWait.until { view.received.count == 2 })
        XCTAssertEqual(view.received[1].map(\.selected), [false, true])

        presenter.didTapCloseButton()
        XCTAssertEqual(router.dismissed.count, 1)
        let chainAsset = ChainAsset(chain: beta, asset: CovJSelFixture.asset("b"))
        presenter.assetSelection(didCompleteWith: chainAsset, contextTag: 4)
        presenter.assetSelection(didCompleteWith: nil, contextTag: nil)
        XCTAssertEqual(output.completions.count, 2)
        XCTAssertEqual(output.completions.first?.chainAsset, chainAsset)
        XCTAssertEqual(output.completions.first?.tag, 4)
        XCTAssertNil(output.completions.last?.chainAsset)
        presenter.applyLocalization()
    }

    @MainActor
    func testPresenterLogsFetchFailureWithoutUpdatingTheView() throws {
        let interactor = CovJSelMultichainInteractorStub(chains: .failure(CovJError("chains")))
        let input = CovJSelSelectAssetInputSpy()
        let view = CovJSelMultichainViewSpy()
        let presenter = MultichainAssetSelectionPresenter(
            interactor: interactor,
            router: CovJSelDismissSpy(),
            localizationManager: try CovJSelFixture.manager(),
            viewModelFactory: MultichainAssetSelectionViewModelFactoryImpl(),
            logger: Logger.shared,
            selectAssetModuleOutput: nil
        )
        presenter.selectAssetModuleInput = input
        presenter.didLoad(view: view)
        CovJWait.drain(0.2)
        XCTAssertTrue(view.received.isEmpty)
        XCTAssertTrue(input.updates.isEmpty)

        let empty = CovJSelMultichainInteractorStub(chains: .success([]))
        let emptyPresenter = MultichainAssetSelectionPresenter(
            interactor: empty,
            router: CovJSelDismissSpy(),
            localizationManager: try CovJSelFixture.manager(),
            viewModelFactory: MultichainAssetSelectionViewModelFactoryImpl(),
            logger: Logger.shared,
            selectAssetModuleOutput: nil
        )
        emptyPresenter.selectAssetModuleInput = input
        emptyPresenter.didLoad(view: view)
        XCTAssertTrue(CovJWait.until { view.received.count == 1 })
        XCTAssertEqual(input.updates.first?.count, 0)
        emptyPresenter.assetSelection(didCompleteWith: nil, contextTag: 1)
    }

    func testInteractorDelegatesToFetchersAndOkxAssetsAreEmpty() async throws {
        let alpha = CovJSelFixture.chain(name: "Alpha", assets: [CovJSelFixture.asset("a")])
        let interactor = MultichainAssetSelectionInteractor(
            chainFetching: CovJSelChainFetchingStub(chains: [alpha]),
            assetFetching: OKXMultichainAssetFetching()
        )
        interactor.setup(with: CovJSelMultichainNoOutput())
        let chains = try await interactor.fetchChains()
        XCTAssertEqual(chains.map(\.chainId), [alpha.chainId])
        let assets = try await interactor.fetchAssets(for: alpha)
        XCTAssertTrue(assets.isEmpty)
    }

    func testOkxChainFetchingKeepsOnlyRankedStoredChains() async throws {
        let repository = ChainRepositoryFactory(storageFacade: SubstrateStorageTestFacade()).createAsyncRepository()
        let ranked = CovJSelFixture.chain(name: "Ranked", rank: 2, assets: [CovJSelFixture.asset("ranked")])
        let unranked = CovJSelFixture.chain(name: "Unranked", assets: [CovJSelFixture.asset("unranked")])
        await repository.save(models: [ranked, unranked], deleteIds: [])
        let chains = try await OKXMultichainChainFetching(chainsRepository: repository).fetchChains()
        XCTAssertEqual(chains.map(\.chainId), [ranked.chainId])
        XCTAssertEqual(chains.first?.rank, 2)
    }

    func testFactoryMarksSelectedChain() {
        let alpha = CovJSelFixture.chain(name: "Alpha", icon: UniversalWalletRegistry.bitcoinIconURL, assets: [])
        let beta = CovJSelFixture.chain(name: "Beta", assets: [])
        let models = MultichainAssetSelectionViewModelFactoryImpl().buildViewModels(chains: [alpha, beta], selectedChainId: beta.chainId)
        XCTAssertEqual(models.map(\.selected), [false, true])
        XCTAssertEqual(models.first?.imageViewModel?.url, UniversalWalletRegistry.bitcoinIconURL)
        XCTAssertTrue(MultichainAssetSelectionViewModelFactoryImpl().buildViewModels(chains: [], selectedChainId: nil).isEmpty)
    }

    @MainActor
    func testControllerEmbedsAssetListShowsChainsAndForwardsTaps() throws {
        let output = CovJSelMultichainOutputSpy()
        let child = UIViewController()
        let controller = MultichainAssetSelectionViewController(
            output: output,
            localizationManager: try CovJSelFixture.manager(),
            selectAssetViewController: child
        )
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }

        XCTAssertEqual(output.loaded, 1)
        XCTAssertTrue(controller.children.contains(child))
        XCTAssertTrue(child.view.superview === controller.rootView.selectAssetContainerView)

        let alpha = CovJSelFixture.chain(name: "Alpha", icon: UniversalWalletRegistry.bitcoinIconURL, assets: [])
        let beta = CovJSelFixture.chain(name: "Beta", assets: [])
        let models = MultichainAssetSelectionViewModelFactoryImpl().buildViewModels(chains: [alpha, beta], selectedChainId: alpha.chainId)
        let collection = controller.rootView.chainsCollectionView
        XCTAssertEqual(controller.collectionView(collection, numberOfItemsInSection: 0), 0)
        controller.didReceive(viewModels: models)
        XCTAssertEqual(controller.collectionView(collection, numberOfItemsInSection: 0), 2)
        let first = IndexPath(item: 0, section: 0)
        collection.layoutIfNeeded()
        let cell = try XCTUnwrap(collection.cellForItem(at: first) as? ChainSelectionCollectionCell)
        XCTAssertEqual(rgba(cell.iconBackgroundView.backgroundColor), rgba(R.color.colorWhite()), "the selected chain is highlighted")
        let second = try XCTUnwrap(collection.cellForItem(at: IndexPath(item: 1, section: 0)) as? ChainSelectionCollectionCell)
        XCTAssertEqual(rgba(second.iconBackgroundView.backgroundColor), rgba(R.color.colorWhite8()))
        XCTAssertEqual((collection.collectionViewLayout as? UICollectionViewFlowLayout)?.scrollDirection, .horizontal)
        controller.collectionView(collection, willDisplay: UICollectionViewCell(), forItemAt: first)
        controller.collectionView(collection, didSelectItemAt: IndexPath(item: 1, section: 0))
        XCTAssertEqual(output.selected.map(\.chainId), [beta.chainId])

        controller.rootView.topBar.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.closes, 1)
        controller.applyLocalization()
        XCTAssertEqual(controller.rootView.locale.identifier, "en")
    }

    func testChainCellTintsSelectedIconAndResetsOnReuse() throws {
        let alpha = CovJSelFixture.chain(name: "Alpha", icon: UniversalWalletRegistry.bitcoinIconURL, assets: [])
        let selected = ChainSelectionCollectionCellModel(chain: alpha, imageViewModel: CovJSelFixture.offlineIcon, selected: true)
        let plain = ChainSelectionCollectionCellModel(chain: alpha, imageViewModel: CovJSelFixture.offlineIcon, selected: false)
        let cell = ChainSelectionCollectionCell(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        cell.layoutIfNeeded()
        XCTAssertEqual(cell.iconBackgroundView.layer.cornerRadius, 20, accuracy: 0.5)

        cell.bind(viewModel: selected)
        XCTAssertEqual(rgba(cell.iconBackgroundView.backgroundColor), rgba(R.color.colorWhite()))
        XCTAssertTrue(CovJWait.until(timeout: 3) { cell.chainIconImageView.image != nil })

        cell.prepareForReuse()
        XCTAssertNil(cell.chainIconImageView.image)
        cell.bind(viewModel: plain)
        XCTAssertEqual(rgba(cell.iconBackgroundView.backgroundColor), rgba(R.color.colorWhite8()))
        XCTAssertTrue(CovJWait.until(timeout: 3) { cell.chainIconImageView.image?.renderingMode == .alwaysOriginal })

        cell.bind(viewModel: nil)
        XCTAssertEqual(rgba(cell.iconBackgroundView.backgroundColor), rgba(R.color.colorWhite8()))
    }
}

final class CovJSelMultichainNoOutput: MultichainAssetSelectionInteractorOutput {}
