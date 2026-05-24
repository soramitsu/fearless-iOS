import XCTest
import UIKit
import FearlessFoundation
import SSFModels
@testable import fearless

final class NftCollectionTests: XCTestCase {
    func testDidLoad_whenViewProvided_thenSetsUpInteractor() {
        let interactor = NftCollectionInteractorInputSpy()
        let presenter = createPresenter(interactor: interactor)
        let view = NftCollectionViewSpy()

        presenter.didLoad(view: view)

        XCTAssertTrue(interactor.output === presenter)
    }

    func testViewAppearedAndLoadNext_whenCalled_thenTriggersInteractor() {
        let interactor = NftCollectionInteractorInputSpy()
        let presenter = createPresenter(interactor: interactor)

        presenter.viewAppeared()
        presenter.loadNext()

        XCTAssertEqual(interactor.initialSetupCallCount, 1)
        XCTAssertEqual(interactor.fetchDataCallCount, 1)
    }

    func testDidReceiveCollection_whenInteractorProvidesCollection_thenBuildsAndDisplaysViewModel() {
        let collection = Self.makeCollection()
        let viewModel = NftCollectionViewModel(
            collectionName: "Collection",
            collectionImage: nil,
            collectionDescription: "Description",
            ownedCellModels: [],
            availableCellModels: []
        )
        let factory = NftCollectionViewModelFactorySpy(viewModel: viewModel)
        let presenter = createPresenter(viewModelFactory: factory)
        let view = NftCollectionViewSpy()

        presenter.didLoad(view: view)
        presenter.didReceive(collection: collection)

        XCTAssertEqual(factory.receivedCollection, collection)
        XCTAssertEqual(view.viewModel?.collectionName, "Collection")
    }

    func testNavigationActions_whenTapped_thenRouteExpectedDestinations() {
        let nft = Self.makeNft()
        let wallet = AccountGenerator.generateMetaAccount()
        let router = NftCollectionRouterSpy()
        let presenter = createPresenter(
            router: router,
            address: "wallet-address",
            wallet: wallet
        )
        let view = NftCollectionViewSpy()

        presenter.didLoad(view: view)
        presenter.didBackButtonTapped()
        presenter.didSelect(nft: nft, type: .owned)
        presenter.didTapActionButton(nft: nft, type: .owned)

        XCTAssertTrue(router.dismissedView === view)
        XCTAssertEqual(router.detailsNft, nft)
        XCTAssertEqual(router.detailsType, .owned)
        XCTAssertEqual(router.detailsAddress, "wallet-address")
        XCTAssertEqual(router.detailsWallet?.metaId, wallet.metaId)
        XCTAssertTrue(router.detailsView === view)
        XCTAssertEqual(router.sendNft, nft)
        XCTAssertEqual(router.sendWallet?.metaId, wallet.metaId)
        XCTAssertTrue(router.sendView === view)
    }

    func testDidTapActionButton_whenAvailableNft_thenSharesSources() {
        let nft = Self.makeNft()
        let router = NftCollectionRouterSpy()
        let presenter = createPresenter(router: router, address: "wallet-address")
        let view = NftCollectionViewSpy()

        presenter.didLoad(view: view)
        presenter.didTapActionButton(nft: nft, type: .available)

        XCTAssertTrue(router.shareView === view)
        XCTAssertGreaterThanOrEqual(router.sharedSources.count, 4)
    }

    private func createPresenter(
        interactor: NftCollectionInteractorInput = NftCollectionInteractorInputSpy(),
        router: NftCollectionRouterInput = NftCollectionRouterSpy(),
        viewModelFactory: NftCollectionViewModelFactoryProtocol = NftCollectionViewModelFactorySpy(),
        address: String = "wallet-address",
        wallet: MetaAccountModel = AccountGenerator.generateMetaAccount()
    ) -> NftCollectionPresenter {
        NftCollectionPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            viewModelFactory: viewModelFactory,
            address: address,
            wallet: wallet
        )
    }

    private static func makeNft(title: String = "NFT") -> NFT {
        let chain = ChainModelGenerator.generate(count: 1).first!
        let collection = NFTCollection(
            address: "0xcollection",
            numberOfTokens: 1,
            isSpam: false,
            title: "Collection",
            name: "Collection",
            creator: "Creator",
            price: nil,
            media: nil,
            tokenType: .erc721,
            desc: "Description",
            opensea: nil,
            chain: chain,
            totalSupply: "1",
            nfts: nil,
            availableNfts: nil
        )

        return NFT(
            chain: chain,
            tokenId: "2a",
            title: title,
            description: "NFT description",
            smartContract: "0xcontract",
            metadata: nil,
            mediaThumbnail: nil,
            media: nil,
            tokenType: .erc721,
            collectionName: collection.displayName,
            collection: collection
        )
    }

    private static func makeCollection() -> NFTCollection {
        let nft = makeNft()
        return NFTCollection(
            address: "0xcollection",
            numberOfTokens: 1,
            isSpam: false,
            title: "Collection",
            name: "Collection",
            creator: "Creator",
            price: nil,
            media: nil,
            tokenType: .erc721,
            desc: "Description",
            opensea: nil,
            chain: nft.chain,
            totalSupply: "1",
            nfts: [nft],
            availableNfts: []
        )
    }
}

private final class NftCollectionViewSpy: NftCollectionViewInput {
    let controller = UIViewController()
    let isSetup = false
    private(set) var viewModel: NftCollectionViewModel?

    func didReceive(viewModel: NftCollectionViewModel) {
        self.viewModel = viewModel
    }
}

private final class NftCollectionInteractorInputSpy: NftCollectionInteractorInput {
    private(set) weak var output: NftCollectionInteractorOutput?
    private(set) var initialSetupCallCount = 0
    private(set) var fetchDataCallCount = 0

    func initialSetup() {
        initialSetupCallCount += 1
    }

    func setup(with output: NftCollectionInteractorOutput) {
        self.output = output
    }

    func fetchData() {
        fetchDataCallCount += 1
    }
}

private final class NftCollectionRouterSpy: NftCollectionRouterInput {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var detailsView: ControllerBackedProtocol?
    private(set) weak var sendView: ControllerBackedProtocol?
    private(set) weak var shareView: ControllerBackedProtocol?
    private(set) var detailsNft: NFT?
    private(set) var detailsType: NftType?
    private(set) var detailsWallet: MetaAccountModel?
    private(set) var detailsAddress: String?
    private(set) var sendNft: NFT?
    private(set) var sendWallet: MetaAccountModel?
    private(set) var sharedSources: [Any] = []

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func openNftDetails(
        nft: NFT,
        type: NftType,
        wallet: MetaAccountModel,
        address: String,
        from view: ControllerBackedProtocol?
    ) {
        detailsNft = nft
        detailsType = type
        detailsWallet = wallet
        detailsAddress = address
        detailsView = view
    }

    func openSend(nft: NFT, wallet: MetaAccountModel, from view: ControllerBackedProtocol?) {
        sendNft = nft
        sendWallet = wallet
        sendView = view
    }

    func share(
        source: UIActivityItemSource,
        from view: ControllerBackedProtocol?,
        with completionHandler: SharingCompletionHandler?
    ) {
        sharedSources = [source]
        shareView = view
        completionHandler?(true)
    }

    func share(
        sources: [Any],
        from view: ControllerBackedProtocol?,
        with completionHandler: SharingCompletionHandler?
    ) {
        sharedSources = sources
        shareView = view
        completionHandler?(true)
    }
}

private final class NftCollectionViewModelFactorySpy: NftCollectionViewModelFactoryProtocol {
    private(set) var receivedCollection: NFTCollection?
    private let viewModel: NftCollectionViewModel

    init(
        viewModel: NftCollectionViewModel = NftCollectionViewModel(
            collectionName: "Collection",
            collectionImage: nil,
            collectionDescription: nil,
            ownedCellModels: [],
            availableCellModels: []
        )
    ) {
        self.viewModel = viewModel
    }

    func buildViewModel(from collection: NFTCollection, locale _: Locale) -> NftCollectionViewModel {
        receivedCollection = collection
        return viewModel
    }
}
