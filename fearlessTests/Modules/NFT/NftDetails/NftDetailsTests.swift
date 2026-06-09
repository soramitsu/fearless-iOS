import XCTest
import UIKit
import FearlessFoundation
import SSFModels
@testable import fearless

final class NftDetailsTests: XCTestCase {
    func testDidLoad_whenViewProvided_thenSetsUpInteractor() {
        let interactor = NftDetailsInteractorInputSpy()
        let presenter = createPresenter(interactor: interactor)
        let view = NftDetailsViewSpy()

        presenter.didLoad(view: view)

        XCTAssertTrue(interactor.output === presenter)
    }

    func testDidReceiveNft_whenInteractorProvidesNft_thenBuildsAndDisplaysViewModel() {
        let nft = Self.makeNft(title: "Fearless NFT")
        let factory = NftDetailViewModelFactorySpy()
        let presenter = createPresenter(viewModelFactory: factory, nft: nft)
        let view = NftDetailsViewSpy()

        presenter.didLoad(view: view)
        presenter.didReceive(nft: nft)

        XCTAssertEqual(factory.receivedNft, nft)
        XCTAssertEqual(factory.receivedType, .owned)
        XCTAssertNil(factory.receivedOwnerString)
        XCTAssertEqual(view.viewModel?.nftName, "Fearless NFT")
    }

    func testDidReceiveOwners_whenInteractorProvidesOwners_thenBuildsOwnerStringAndRefreshesViewModel() {
        let nft = Self.makeNft(title: "Owned NFT")
        let factory = NftDetailViewModelFactorySpy(ownerString: "wallet-address and others")
        let presenter = createPresenter(
            address: "wallet-address",
            viewModelFactory: factory,
            nft: nft
        )
        let view = NftDetailsViewSpy()

        presenter.didLoad(view: view)
        presenter.didReceive(owners: ["wallet-address", "other-address"])

        XCTAssertEqual(factory.receivedOwners, ["wallet-address", "other-address"])
        XCTAssertEqual(factory.receivedOwnerAddress, "wallet-address")
        XCTAssertEqual(factory.receivedOwnerString, "wallet-address and others")
        XCTAssertEqual(view.viewModel?.owner, "wallet-address and others")
    }

    func testNavigationActions_whenTapped_thenRouteExpectedDestinations() {
        let nft = Self.makeNft()
        let wallet = AccountGenerator.generateMetaAccount()
        let router = NftDetailsRouterSpy()
        let presenter = createPresenter(router: router, nft: nft, wallet: wallet)
        let view = NftDetailsViewSpy()

        presenter.didLoad(view: view)
        presenter.didBackButtonTapped()
        presenter.didTapSendButton()
        presenter.didTapCopy()

        XCTAssertTrue(router.dismissedView === view)
        XCTAssertEqual(router.sendNft, nft)
        XCTAssertEqual(router.sendWallet?.metaId, wallet.metaId)
        XCTAssertTrue(router.sendView === view)
        XCTAssertTrue(router.presentedStatus is CommonCopiedEvent)
        XCTAssertEqual(router.presentStatusAnimated, true)
    }

    func testDidTapShareButton_whenViewModelExists_thenSharesSourcesFromViewModel() {
        let router = NftDetailsRouterSpy()
        let factory = NftDetailViewModelFactorySpy(
            viewModel: Self.makeViewModel(
                nft: Self.makeNft(),
                owner: "owner-address",
                collectionName: "Collection",
                creator: "Creator",
                tokenId: "42",
                tokenType: NFTTokenType.erc721.rawValue
            )
        )
        let presenter = createPresenter(router: router, viewModelFactory: factory)
        let view = NftDetailsViewSpy()

        presenter.didLoad(view: view)
        presenter.didReceive(nft: Self.makeNft())
        presenter.didTapShareButton()

        XCTAssertTrue(router.shareView === view)
        XCTAssertGreaterThanOrEqual(router.sharedSources.count, 6)
    }

    private func createPresenter(
        interactor: NftDetailsInteractorInput = NftDetailsInteractorInputSpy(),
        router: NftDetailsRouterInput = NftDetailsRouterSpy(),
        address: String = "wallet-address",
        viewModelFactory: NftDetailViewModelFactoryProtocol = NftDetailViewModelFactorySpy(),
        nft: NFT = NftDetailsTests.makeNft(),
        wallet: MetaAccountModel = AccountGenerator.generateMetaAccount(),
        type: NftType = .owned
    ) -> NftDetailsPresenter {
        NftDetailsPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            address: address,
            viewModelFactory: viewModelFactory,
            nft: nft,
            wallet: wallet,
            type: type
        )
    }

    private static func makeNft(title: String = "NFT") -> NFT {
        let chain = ChainModelGenerator.generate(count: 1).first!
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
            collectionName: "Collection",
            collection: nil
        )
    }

    private static func makeViewModel(
        nft: NFT,
        owner: String? = nil,
        collectionName: String? = nil,
        creator: String? = nil,
        tokenId: String? = nil,
        tokenType: String? = nil
    ) -> NftDetailViewModel {
        NftDetailViewModel(
            nftName: nft.displayName,
            nftDescription: nft.displayDescription,
            collectionName: collectionName,
            owner: owner,
            tokenId: tokenId,
            chain: nft.chain.name,
            imageViewModel: nil,
            nft: nft,
            tokenType: tokenType,
            nftType: .owned,
            creator: creator,
            priceString: nil
        )
    }
}

private final class NftDetailsViewSpy: NftDetailsViewInput {
    let controller = UIViewController()
    let isSetup = false
    private(set) var viewModel: NftDetailViewModel?

    func didReceive(viewModel: NftDetailViewModel) {
        self.viewModel = viewModel
    }
}

private final class NftDetailsInteractorInputSpy: NftDetailsInteractorInput {
    private(set) weak var output: NftDetailsInteractorOutput?

    func setup(with output: NftDetailsInteractorOutput) {
        self.output = output
    }
}

private final class NftDetailsRouterSpy: NftDetailsRouterInput {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var sendView: ControllerBackedProtocol?
    private(set) weak var shareView: ControllerBackedProtocol?
    private(set) var sendNft: NFT?
    private(set) var sendWallet: MetaAccountModel?
    private(set) var sharedSources: [Any] = []
    private(set) var presentedStatus: ApplicationStatusAlertEvent?
    private(set) var presentStatusAnimated: Bool?
    private(set) var dismissedStatus: ApplicationStatusAlertEvent?
    private(set) var dismissStatusAnimated: Bool?

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func openSend(nft: NFT, wallet: MetaAccountModel, from view: ControllerBackedProtocol?) {
        sendNft = nft
        sendWallet = wallet
        sendView = view
    }

    func presentStatus(with viewModel: ApplicationStatusAlertEvent, animated: Bool) {
        presentedStatus = viewModel
        presentStatusAnimated = animated
    }

    func dismissStatus(with viewModel: ApplicationStatusAlertEvent?, animated: Bool) {
        dismissedStatus = viewModel
        dismissStatusAnimated = animated
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

private final class NftDetailViewModelFactorySpy: NftDetailViewModelFactoryProtocol {
    private(set) var receivedNft: NFT?
    private(set) var receivedType: NftType?
    private(set) var receivedOwnerString: String?
    private(set) var receivedOwners: [String] = []
    private(set) var receivedOwnerAddress: String?
    private let viewModel: NftDetailViewModel?
    private let ownerString: String?

    init(
        viewModel: NftDetailViewModel? = nil,
        ownerString: String? = nil
    ) {
        self.viewModel = viewModel
        self.ownerString = ownerString
    }

    func buildViewModel(with nft: NFT, nftType: NftType, ownerString: String?) -> NftDetailViewModel {
        receivedNft = nft
        receivedType = nftType
        receivedOwnerString = ownerString
        return viewModel ?? NftDetailViewModel(
            nftName: nft.displayName,
            nftDescription: nft.displayDescription,
            collectionName: nft.collection?.displayName,
            owner: ownerString,
            tokenId: nft.tokenId,
            chain: nft.chain.name,
            imageViewModel: nil,
            nft: nft,
            tokenType: nft.tokenType?.rawValue,
            nftType: nftType,
            creator: nft.collection?.creator,
            priceString: nil
        )
    }

    func buildOwnerString(owners: [String], address: String, locale _: Locale) -> String? {
        receivedOwners = owners
        receivedOwnerAddress = address
        return ownerString
    }
}
