import SoraFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class CovHNftDetailsViewSpy: CovHNftHostController, NftDetailsViewInput {
    private(set) var viewModels: [NftDetailViewModel] = []

    func didReceive(viewModel: NftDetailViewModel) {
        viewModels.append(viewModel)
    }
}

final class CovHNftDetailsInteractorSpy: NftDetailsInteractorInput {
    private(set) weak var output: NftDetailsInteractorOutput?

    func setup(with output: NftDetailsInteractorOutput) {
        self.output = output
    }
}

final class CovHNftDetailsRouterSpy: NftDetailsRouterInput {
    private(set) var sends: [NFT] = []
    private(set) var shared: [[Any]] = []
    private(set) var statuses = 0
    private(set) var dismissals = 0

    func openSend(nft: NFT, wallet _: MetaAccountModel, from _: ControllerBackedProtocol?) { sends.append(nft) }
    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }
    func presentStatus(with _: ApplicationStatusAlertEvent, animated _: Bool) { statuses += 1 }
    func dismissStatus(with _: ApplicationStatusAlertEvent?, animated _: Bool) {}
    func share(source _: UIActivityItemSource, from _: ControllerBackedProtocol?, with _: SharingCompletionHandler?) {}
    func share(sources: [Any], from _: ControllerBackedProtocol?, with _: SharingCompletionHandler?) { shared.append(sources) }
}

final class CovHNftDetailsOutputSpy: NftDetailsInteractorOutput {
    private let lock = NSLock()
    private var storedNfts: [NFT] = []
    private var storedOwners: [[String]] = []

    var nfts: [NFT] { lock.lock(); defer { lock.unlock() }; return storedNfts }
    var owners: [[String]] { lock.lock(); defer { lock.unlock() }; return storedOwners }

    func didReceive(nft: NFT) {
        lock.lock()
        storedNfts.append(nft)
        lock.unlock()
    }

    func didReceive(owners: [String]) {
        lock.lock()
        storedOwners.append(owners)
        lock.unlock()
    }
}

final class CovHNftDetailsPresenterTests: XCTestCase {
    private func makePresenter(nft: NFT, type: NftType = .owned) -> (NftDetailsPresenter, CovHNftDetailsViewSpy, CovHNftDetailsInteractorSpy, CovHNftDetailsRouterSpy) {
        let view = CovHNftDetailsViewSpy()
        let interactor = CovHNftDetailsInteractorSpy()
        let router = CovHNftDetailsRouterSpy()
        let presenter = NftDetailsPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            address: "covh-owner",
            viewModelFactory: NftDetailViewModelFactory(),
            nft: nft,
            wallet: CovHNftFixtures.wallet(),
            type: type
        )
        presenter.didLoad(view: view)
        return (presenter, view, interactor, router)
    }

    func testViewModelsOwnersAndActions() {
        let chain = CovHNftFixtures.chain(name: "Details chain")
        let nft = CovHNftFixtures.nft(chain: chain)
        let (presenter, view, interactor, router) = makePresenter(nft: nft)
        XCTAssertTrue(interactor.output === presenter)

        presenter.didReceive(nft: nft)
        XCTAssertEqual(view.viewModels.last?.nftName, "CovH Token")
        XCTAssertNil(view.viewModels.last?.owner)

        presenter.didReceive(owners: ["someone", "covh-owner"])
        let owner = view.viewModels.last?.owner
        XCTAssertEqual(owner, R.string.localizable.commonAndOthersPlaceholder("covh-owner", preferredLanguages: presenter.selectedLocale.rLanguages))

        presenter.didTapSendButton()
        presenter.didTapCopy()
        presenter.didBackButtonTapped()
        presenter.applyLocalization()
        XCTAssertEqual(router.sends, [nft])
        XCTAssertEqual(router.statuses, 1)
        XCTAssertEqual(router.dismissals, 1)
    }

    func testShareListsViewModelFields() throws {
        let chain = CovHNftFixtures.chain(name: "Share chain")
        let collection = CovHNftFixtures.collection(chain: chain, creator: "creator-2")
        let nft = CovHNftFixtures.nft(chain: chain, collection: collection)
        let (presenter, _, _, router) = makePresenter(nft: nft)

        presenter.didTapShareButton()
        let early = CovHNftFixtures.messages(try XCTUnwrap(router.shared.first))
        XCTAssertEqual(early.count, 1, "only the address is known before a view model exists")

        presenter.didReceive(owners: ["covh-owner"])
        presenter.didTapShareButton()
        let messages = CovHNftFixtures.messages(try XCTUnwrap(router.shared.last))
        XCTAssertEqual(messages.count, 7)
        XCTAssertTrue(messages.contains { $0.hasSuffix(": CovH Collection") })
        XCTAssertTrue(messages.contains { $0.hasSuffix(": covh-owner") })
        XCTAssertTrue(messages.contains { $0.hasSuffix(": creator-2") })
        XCTAssertTrue(messages.contains { $0.hasSuffix(": Share chain") })
        XCTAssertTrue(messages.contains { $0.hasSuffix(": 10") })
        XCTAssertTrue(messages.contains { $0.hasSuffix(": ERC721") })
    }

    func testShareWithThumbnailWaitsForImageLookup() throws {
        let nft = CovHNftFixtures.nft(chain: CovHNftFixtures.chain(), thumbnail: CovHNftFixtures.thumbnailMissingFile)
        let (presenter, _, _, router) = makePresenter(nft: nft, type: .available)
        presenter.didTapShareButton()
        CovHNftWait.until(10) { !router.shared.isEmpty }
        let sources = try XCTUnwrap(router.shared.first)
        XCTAssertFalse(sources.contains { $0 is UIImage })
    }

    func testShareWithLoadableThumbnailIncludesImage() throws {
        let fileURL = try CovHNftFixtures.pngFileURL()
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let nft = CovHNftFixtures.nft(chain: CovHNftFixtures.chain(), thumbnail: fileURL.absoluteString)
        let (presenter, _, _, router) = makePresenter(nft: nft)
        presenter.didTapShareButton()
        CovHNftWait.until(10) { !router.shared.isEmpty }
        XCTAssertTrue(try XCTUnwrap(router.shared.first).contains { $0 is UIImage })
    }
}

final class CovHNftDetailsInteractorTests: XCTestCase {
    func testSetupDeliversNftAndOwners() {
        let chain = CovHNftFixtures.chain()
        let nft = CovHNftFixtures.nft(chain: chain, contract: "0xowners", collection: CovHNftFixtures.collection(chain: chain))
        let service = CovHNftFetchingStub()
        service.owners = .success(["a", "b"])
        let interactor = NftDetailsInteractor(nft: nft, nftFetchingService: service, logger: Logger.shared)
        let output = CovHNftDetailsOutputSpy()

        interactor.setup(with: output)
        XCTAssertEqual(output.nfts, [nft])
        CovHNftWait.until { !output.owners.isEmpty }
        XCTAssertEqual(output.owners, [["a", "b"]])
        XCTAssertEqual(service.ownerRequests.first?.0, "0xowners")
        XCTAssertEqual(service.ownerRequests.first?.1, "0x0a")
    }

    func testOwnerFailureAndMissingNft() {
        let chain = CovHNftFixtures.chain()
        let service = CovHNftFetchingStub()
        service.owners = .failure(CovHNftError.failed)
        let failing = NftDetailsInteractor(
            nft: CovHNftFixtures.nft(chain: chain, collection: CovHNftFixtures.collection(chain: chain)),
            nftFetchingService: service,
            logger: Logger.shared
        )
        let output = CovHNftDetailsOutputSpy()
        failing.setup(with: output)
        CovHNftWait.until { !service.ownerRequests.isEmpty }
        CovHNftWait.spin(0.2)
        XCTAssertEqual(service.ownerRequests.count, 1)
        XCTAssertTrue(output.owners.isEmpty)

        let empty = NftDetailsInteractor(nft: nil, nftFetchingService: service, logger: Logger.shared)
        let emptyOutput = CovHNftDetailsOutputSpy()
        empty.setup(with: emptyOutput)
        CovHNftWait.spin(0.2)
        XCTAssertTrue(emptyOutput.nfts.isEmpty)
        XCTAssertEqual(service.ownerRequests.count, 1)
    }
}

final class CovHNftDetailsFactoryAndRoutingTests: XCTestCase {
    func testViewModelFactory() {
        let chain = CovHNftFixtures.chain(name: "Factory chain")
        let factory = NftDetailViewModelFactory()
        let collection = CovHNftFixtures.collection(chain: chain, creator: "maker")
        let nft = CovHNftFixtures.nft(chain: chain, thumbnail: "https://image.invalid/a.png", collection: collection)

        let viewModel = factory.buildViewModel(with: nft, nftType: .available, ownerString: "owner")
        XCTAssertEqual(viewModel.nftName, "CovH Token")
        XCTAssertEqual(viewModel.nftDescription, "Token description")
        XCTAssertEqual(viewModel.collectionName, "CovH Collection")
        XCTAssertEqual(viewModel.owner, "owner")
        XCTAssertEqual(viewModel.tokenId, "10")
        XCTAssertEqual(viewModel.chain, "Factory chain")
        XCTAssertNotNil(viewModel.imageViewModel)
        XCTAssertEqual(viewModel.tokenType, "ERC721")
        XCTAssertEqual(viewModel.creator, "maker")
        XCTAssertNil(viewModel.priceString)

        let bare = factory.buildViewModel(
            with: CovHNftFixtures.nft(chain: chain, tokenId: nil, tokenType: nil),
            nftType: .owned,
            ownerString: nil
        )
        XCTAssertEqual(bare.tokenId, "")
        XCTAssertNil(bare.imageViewModel)
        XCTAssertNil(bare.tokenType)
        XCTAssertNil(bare.creator)

        let locale = Locale(identifier: "en")
        XCTAssertEqual(factory.buildOwnerString(owners: [], address: "me", locale: locale), "")
        XCTAssertEqual(factory.buildOwnerString(owners: ["other"], address: "me", locale: locale), "other")
        XCTAssertEqual(
            factory.buildOwnerString(owners: ["other", "me"], address: "me", locale: locale),
            R.string.localizable.commonAndOthersPlaceholder("me", preferredLanguages: locale.rLanguages)
        )
    }

    func testRouterRefusesSubstrateSendAndAssemblyBuildsScreen() throws {
        let host = CovHNftHostController()
        let navigation = CovHNftNavigationSpy(rootViewController: host)
        let chain = CovHNftFixtures.chain()
        let nft = CovHNftFixtures.nft(chain: chain, title: "Assembled NFT")

        NftDetailsRouter().openSend(nft: nft, wallet: CovHNftFixtures.wallet(), from: host)
        XCTAssertTrue(navigation.pushed.isEmpty)

        let module = try XCTUnwrap(NftDetailsAssembly.configureModule(nft: nft, wallet: CovHNftFixtures.wallet(), address: "addr", type: .available))
        let controller = try XCTUnwrap(module.view.controller as? NftDetailsViewController)
        controller.loadViewIfNeeded()
        XCTAssertEqual(controller.rootView.navigationTitleLabel.text, "Assembled NFT")
        XCTAssertTrue(controller.rootView.sendButton.isHidden)
    }
}

final class CovHNftDetailsViewOutputSpy: NftDetailsViewOutput {
    private(set) var calls: [String] = []

    func didLoad(view _: NftDetailsViewInput) { calls.append("load") }
    func didBackButtonTapped() { calls.append("back") }
    func didTapSendButton() { calls.append("send") }
    func didTapShareButton() { calls.append("share") }
    func didTapCopy() { calls.append("copy") }
}

final class CovHNftDetailsViewTests: XCTestCase {
    private func viewModel(nft: NFT, type: NftType, owner: String?, price: String? = nil) -> NftDetailViewModel {
        NftDetailViewModel(
            nftName: "Name",
            nftDescription: "Description",
            collectionName: owner == nil ? nil : "Collection",
            owner: owner,
            tokenId: owner == nil ? nil : "7",
            chain: owner == nil ? nil : "Chain",
            imageViewModel: nil,
            nft: nft,
            tokenType: "ERC1155",
            nftType: type,
            creator: owner == nil ? nil : "Creator",
            priceString: price
        )
    }

    func testControllerForwardsButtonsAndCopies() {
        let output = CovHNftDetailsViewOutputSpy()
        let controller = NftDetailsViewController(output: output, localizationManager: LocalizationManager.shared)
        controller.loadViewIfNeeded()
        let root = controller.rootView

        root.navigationBar.backButton.sendActions(for: .touchUpInside)
        root.sendButton.sendActions(for: .touchUpInside)
        root.shareButton.sendActions(for: .touchUpInside)
        root.ownerView.onCopy?()
        root.tokenIdView.onCopy?()
        root.creatorView.onCopy?()

        XCTAssertEqual(output.calls, ["load", "back", "send", "share", "copy", "copy", "copy"])
        let languages = controller.selectedLocale.rLanguages
        XCTAssertEqual(root.ownerView.titleLabel.text, R.string.localizable.nftOwnerTitle(preferredLanguages: languages))
        XCTAssertEqual(root.shareButton.imageWithTitleView?.title, R.string.localizable.commonShare(preferredLanguages: languages))

        let nft = CovHNftFixtures.nft(chain: CovHNftFixtures.chain())
        controller.didReceive(viewModel: viewModel(nft: nft, type: .owned, owner: "Owner", price: "1 CVH"))
        XCTAssertEqual(root.navigationTitleLabel.text, "Name")
        XCTAssertEqual(root.ownerView.valueLabel.text, "Owner")
        XCTAssertFalse(root.priceView.isHidden)
        XCTAssertFalse(root.sendButton.isHidden)
    }

    func testLayoutHidesMissingFieldsAndShowsFallbackImage() {
        let layout = NftDetailsViewLayout(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        layout.locale = Locale(identifier: "en")
        let chain = CovHNftFixtures.chain()

        layout.bind(viewModel: viewModel(nft: CovHNftFixtures.nft(chain: chain), type: .available, owner: nil))
        XCTAssertTrue(layout.collectionView.isHidden)
        XCTAssertTrue(layout.ownerView.isHidden)
        XCTAssertTrue(layout.creatorView.isHidden)
        XCTAssertTrue(layout.tokenIdView.isHidden)
        XCTAssertTrue(layout.networkView.isHidden)
        XCTAssertTrue(layout.priceView.isHidden)
        XCTAssertTrue(layout.sendButton.isHidden)
        XCTAssertEqual(layout.desciptionLabel.text, "Description")
        XCTAssertEqual(layout.tokenTypeView.valueLabel.text, "ERC1155")
        XCTAssertEqual(layout.mediaView.contentMode, .scaleAspectFit)
        XCTAssertEqual(layout.networkView.titleLabel.text, R.string.localizable.commonNetwork(preferredLanguages: layout.locale.rLanguages))

        let withMedia = CovHNftFixtures.nft(chain: chain, thumbnail: CovHNftFixtures.thumbnailMissingFile)
        layout.bind(viewModel: viewModel(nft: withMedia, type: .owned, owner: "Owner"))
        XCTAssertFalse(layout.ownerView.isHidden)
        XCTAssertFalse(layout.sendButton.isHidden)
        XCTAssertEqual(layout.creatorView.valueLabel.text, "Creator")
        XCTAssertEqual(layout.tokenIdView.valueLabel.text, "7")
        XCTAssertEqual(layout.networkView.valueLabel.text, "Chain")
        XCTAssertEqual(layout.collectionView.valueLabel.text, "Collection")
    }
}
