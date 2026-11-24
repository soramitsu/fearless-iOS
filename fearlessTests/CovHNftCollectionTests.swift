import SoraFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class CovHNftCollectionViewSpy: CovHNftHostController, NftCollectionViewInput {
    private(set) var viewModels: [NftCollectionViewModel] = []

    func didReceive(viewModel: NftCollectionViewModel) {
        viewModels.append(viewModel)
    }
}

final class CovHNftCollectionInteractorSpy: NftCollectionInteractorInput {
    private(set) weak var output: NftCollectionInteractorOutput?
    private(set) var initialSetups = 0
    private(set) var fetches = 0

    func initialSetup() { initialSetups += 1 }
    func setup(with output: NftCollectionInteractorOutput) { self.output = output }
    func fetchData() { fetches += 1 }
}

final class CovHNftCollectionRouterSpy: NftCollectionRouterInput {
    private(set) var details: [(NFT, NftType, String)] = []
    private(set) var sends: [NFT] = []
    private(set) var shared: [[Any]] = []
    private(set) var dismissals = 0

    func openNftDetails(nft: NFT, type: NftType, wallet _: MetaAccountModel, address: String, from _: ControllerBackedProtocol?) {
        details.append((nft, type, address))
    }

    func openSend(nft: NFT, wallet _: MetaAccountModel, from _: ControllerBackedProtocol?) {
        sends.append(nft)
    }

    func dismiss(view _: ControllerBackedProtocol?) {
        dismissals += 1
    }

    func share(source _: UIActivityItemSource, from _: ControllerBackedProtocol?, with _: SharingCompletionHandler?) {}

    func share(sources: [Any], from _: ControllerBackedProtocol?, with _: SharingCompletionHandler?) {
        shared.append(sources)
    }
}

final class CovHNftCollectionOutputSpy: NftCollectionInteractorOutput {
    private let lock = NSLock()
    private var stored: [NFTCollection] = []

    var collections: [NFTCollection] { lock.lock(); defer { lock.unlock() }; return stored }

    func didReceive(collection: NFTCollection) {
        lock.lock()
        stored.append(collection)
        lock.unlock()
    }
}

final class CovHNftCollectionPresenterTests: XCTestCase {
    private func makePresenter() -> (NftCollectionPresenter, CovHNftCollectionViewSpy, CovHNftCollectionInteractorSpy, CovHNftCollectionRouterSpy) {
        let view = CovHNftCollectionViewSpy()
        let interactor = CovHNftCollectionInteractorSpy()
        let router = CovHNftCollectionRouterSpy()
        let presenter = NftCollectionPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            viewModelFactory: NftCollectionViewModelFactory(),
            address: "covh-owner",
            wallet: CovHNftFixtures.wallet()
        )
        presenter.didLoad(view: view)
        return (presenter, view, interactor, router)
    }

    func testLifecycleAndNavigation() {
        let (presenter, view, interactor, router) = makePresenter()
        XCTAssertTrue(interactor.output === presenter)
        presenter.viewAppeared()
        presenter.loadNext()
        presenter.didBackButtonTapped()
        presenter.applyLocalization()

        let chain = CovHNftFixtures.chain()
        let nft = CovHNftFixtures.nft(chain: chain)
        presenter.didSelect(nft: nft, type: .available)
        presenter.didTapActionButton(nft: nft, type: .owned)

        XCTAssertEqual(interactor.initialSetups, 1)
        XCTAssertEqual(interactor.fetches, 1)
        XCTAssertEqual(router.dismissals, 1)
        XCTAssertEqual(router.details.first?.0, nft)
        XCTAssertEqual(router.details.first?.2, "covh-owner")
        XCTAssertEqual(router.sends, [nft])

        presenter.didReceive(collection: CovHNftFixtures.collection(chain: chain, nfts: [nft]))
        XCTAssertEqual(view.viewModels.first?.collectionName, "CovH Collection")
        XCTAssertEqual(view.viewModels.first?.ownedCellModels.count, 1)
    }

    func testShareWithoutImageListsEveryKnownField() throws {
        let (presenter, _, _, router) = makePresenter()
        let chain = CovHNftFixtures.chain(name: "Share chain")
        let collection = CovHNftFixtures.collection(chain: chain, creator: "creator-1")
        let nft = CovHNftFixtures.nft(chain: chain, tokenId: "0x0a", collection: collection)

        presenter.didTapActionButton(nft: nft, type: .available)

        let sources = try XCTUnwrap(router.shared.first)
        let messages = CovHNftFixtures.messages(sources)
        XCTAssertEqual(messages.count, 7)
        XCTAssertTrue(messages[0].contains("covh-owner"))
        XCTAssertTrue(messages.contains { $0.hasSuffix(": CovH Collection") })
        XCTAssertTrue(messages.contains { $0.hasSuffix(": creator-1") })
        XCTAssertTrue(messages.contains { $0.hasSuffix(": Share chain") })
        XCTAssertTrue(messages.contains { $0.hasSuffix(": 10") })
        XCTAssertTrue(messages.contains { $0.hasSuffix(": ERC721") })
        XCTAssertFalse(sources.contains { $0 is UIImage })
    }

    func testShareMinimalNftOmitsOptionalFields() throws {
        let (presenter, _, _, router) = makePresenter()
        let nft = CovHNftFixtures.nft(chain: CovHNftFixtures.chain(), tokenId: nil, tokenType: nil, collection: nil)

        presenter.didTapActionButton(nft: nft, type: .available)

        let messages = CovHNftFixtures.messages(try XCTUnwrap(router.shared.first))
        XCTAssertEqual(messages.count, 3, "address, owner and network only")
    }

    func testShareLoadsThumbnailImageWhenAvailable() throws {
        let (presenter, _, _, router) = makePresenter()
        let fileURL = try CovHNftFixtures.pngFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let nft = CovHNftFixtures.nft(chain: CovHNftFixtures.chain(), thumbnail: fileURL.absoluteString)

        presenter.didTapActionButton(nft: nft, type: .available)
        CovHNftWait.until(10) { !router.shared.isEmpty }

        let sources = try XCTUnwrap(router.shared.first)
        XCTAssertTrue(sources.contains { $0 is UIImage })
    }

    func testShareSkipsImageThatCannotBeLoaded() throws {
        let (presenter, _, _, router) = makePresenter()
        let nft = CovHNftFixtures.nft(chain: CovHNftFixtures.chain(), thumbnail: CovHNftFixtures.thumbnailMissingFile)

        presenter.didTapActionButton(nft: nft, type: .available)
        CovHNftWait.until(10) { !router.shared.isEmpty }

        let sources = try XCTUnwrap(router.shared.first)
        XCTAssertFalse(sources.contains { $0 is UIImage })
        XCTAssertFalse(CovHNftFixtures.messages(sources).isEmpty)
    }
}

final class CovHNftCollectionInteractorTests: XCTestCase {
    func testSetupDeliversCollectionAndPagesAvailableNfts() {
        let chain = CovHNftFixtures.chain()
        let owned = CovHNftFixtures.nft(chain: chain, tokenId: "0x01")
        let other = CovHNftFixtures.nft(chain: chain, tokenId: "0x02")
        let third = CovHNftFixtures.nft(chain: chain, tokenId: "0x03")
        let service = CovHNftFetchingStub()
        service.batch = .success(NFTBatch(nfts: [owned, other], nextTokenId: "next"))
        let interactor = NftCollectionInteractor(
            collection: CovHNftFixtures.collection(chain: chain, address: "0xpaged", nfts: [owned]),
            nftFetchingService: service
        )
        let output = CovHNftCollectionOutputSpy()

        interactor.setup(with: output)
        XCTAssertEqual(output.collections.count, 1)

        interactor.fetchData()
        CovHNftWait.spin(0.2)
        XCTAssertTrue(service.batchRequests.isEmpty, "paging starts only after the first appearance")

        interactor.initialSetup()
        CovHNftWait.until { output.collections.count == 2 }
        XCTAssertEqual(output.collections.last?.availableNfts, [other])

        service.batch = .success(NFTBatch(nfts: [third], nextTokenId: nil))
        interactor.fetchData()
        CovHNftWait.until { output.collections.count == 3 }
        XCTAssertEqual(output.collections.last?.availableNfts, [other, third])
        XCTAssertEqual(service.batchRequests.map(\.0), ["0xpaged", "0xpaged"])
        XCTAssertEqual(service.batchRequests.map(\.1), [nil, "next"])

        interactor.initialSetup()
        CovHNftWait.spin(0.2)
        XCTAssertEqual(service.batchRequests.count, 2)
    }

    func testCollectionWithoutAddressIsNotPaged() {
        let service = CovHNftFetchingStub()
        let interactor = NftCollectionInteractor(
            collection: CovHNftFixtures.collection(chain: CovHNftFixtures.chain(), address: nil),
            nftFetchingService: service
        )
        let output = CovHNftCollectionOutputSpy()
        interactor.setup(with: output)
        interactor.initialSetup()
        CovHNftWait.spin(0.3)
        XCTAssertTrue(service.batchRequests.isEmpty)
        XCTAssertEqual(output.collections.count, 1)
    }
}

final class CovHNftCollectionFactoryAndRoutingTests: XCTestCase {
    func testViewModelSeparatesOwnedAndAvailableNfts() throws {
        let chain = CovHNftFixtures.chain()
        let owned = CovHNftFixtures.nft(chain: chain, tokenId: "0x01", thumbnail: "https://image.invalid/1.png")
        let duplicate = CovHNftFixtures.nft(chain: chain, tokenId: "0x01", title: "Duplicate")
        let available = CovHNftFixtures.nft(chain: chain, tokenId: "0x02", title: "Available", description: "Free")
        let collection = CovHNftFixtures.collection(chain: chain, nfts: [owned], availableNfts: [duplicate, available])

        let viewModel = NftCollectionViewModelFactory().buildViewModel(from: collection, locale: Locale(identifier: "en"))

        XCTAssertEqual(viewModel.collectionName, "CovH Collection")
        XCTAssertNotNil(viewModel.collectionImage)
        XCTAssertNil(viewModel.collectionDescription)
        XCTAssertEqual(viewModel.ownedCellModels.map(\.nft), [owned])
        XCTAssertNotNil(viewModel.ownedCellModels.first?.imageViewModel)
        XCTAssertEqual(viewModel.availableCellModels.map(\.name), ["Available"])
        XCTAssertEqual(viewModel.availableCellModels.first?.description, "Free")
        XCTAssertNil(viewModel.availableCellModels.first?.imageViewModel)
    }

    func testViewModelForEmptyCollection() {
        let collection = CovHNftFixtures.collection(chain: CovHNftFixtures.chain(), name: nil)
        let viewModel = NftCollectionViewModelFactory().buildViewModel(from: collection, locale: Locale(identifier: "en"))
        XCTAssertNil(viewModel.collectionName)
        XCTAssertNil(viewModel.collectionImage)
        XCTAssertTrue(viewModel.ownedCellModels.isEmpty)
        XCTAssertTrue(viewModel.availableCellModels.isEmpty)
    }

    func testRouterPushesDetailsAndRefusesSubstrateSend() throws {
        let host = CovHNftHostController()
        let navigation = CovHNftNavigationSpy(rootViewController: host)
        let router = NftCollectionRouter()
        let chain = CovHNftFixtures.chain()
        let wallet = CovHNftFixtures.wallet()
        let nft = CovHNftFixtures.nft(chain: chain)

        router.openNftDetails(nft: nft, type: .owned, wallet: wallet, address: "covh-owner", from: host)
        XCTAssertTrue(navigation.pushed.first is NftDetailsViewController)

        router.openSend(nft: nft, wallet: wallet, from: host)
        XCTAssertEqual(navigation.pushed.count, 1, "substrate NFTs cannot be sent")
    }

    func testAssemblyBuildsCollectionScreen() throws {
        let chain = CovHNftFixtures.chain()
        let module = try XCTUnwrap(NftCollectionAssembly.configureModule(
            collection: CovHNftFixtures.collection(chain: chain, name: "Assembled"),
            wallet: CovHNftFixtures.wallet(),
            address: "covh-owner"
        ))
        let controller = try XCTUnwrap(module.view.controller as? NftCollectionViewController)
        controller.loadViewIfNeeded()
        XCTAssertEqual(controller.rootView.navigationTitleLabel.text, "Assembled")
    }
}
