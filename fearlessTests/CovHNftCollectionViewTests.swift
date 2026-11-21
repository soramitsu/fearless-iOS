import SoraFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class CovHNftCollectionViewOutputSpy: NftCollectionViewOutput, NftCellDelegate {
    private(set) var calls: [String] = []
    private(set) var selected: [(NFT, NftType)] = []
    private(set) var actions: [(NFT, NftType)] = []

    func didLoad(view _: NftCollectionViewInput) { calls.append("load") }
    func viewAppeared() { calls.append("appeared") }
    func didBackButtonTapped() { calls.append("back") }
    func didSelect(nft: NFT, type: NftType) { selected.append((nft, type)) }
    func didTapActionButton(nft: NFT, type: NftType) { actions.append((nft, type)) }
    func loadNext() { calls.append("next") }
    func handle(cellModel: NftCellViewModel) { actions.append((cellModel.nft, cellModel.type)) }
}

final class CovHNftCollectionViewControllerTests: XCTestCase {
    private let locale = Locale(identifier: "en")

    private func cellModel(_ nft: NFT, type: NftType, image: RemoteImageViewModel? = nil) -> NftCellViewModel {
        NftCellViewModel(imageViewModel: image, name: nft.displayName, description: nft.description, type: type, nft: nft, locale: locale)
    }

    private func viewModel(chain: ChainModel, available: Bool) -> NftCollectionViewModel {
        let owned = [
            cellModel(CovHNftFixtures.nft(chain: chain, tokenId: "0x01", title: "Owned 1"), type: .owned),
            cellModel(
                CovHNftFixtures.nft(chain: chain, tokenId: "0x02", title: "Owned 2"),
                type: .owned,
                image: RemoteImageViewModel(url: URL(string: CovHNftFixtures.thumbnailMissingFile)!)
            )
        ]
        let availableModels = available ? [cellModel(CovHNftFixtures.nft(chain: chain, tokenId: "0x03", title: "Free 3"), type: .available)] : []
        return NftCollectionViewModel(
            collectionName: "Collection title",
            collectionImage: BundleImageViewModel(image: UIImage()),
            collectionDescription: "A collection description that is long enough to wrap onto a second line of text.",
            ownedCellModels: owned,
            availableCellModels: availableModels
        )
    }

    func testCollectionScreenRendersSectionsAndForwardsActions() throws {
        let output = CovHNftCollectionViewOutputSpy()
        let controller = NftCollectionViewController(output: output, localizationManager: LocalizationManager.shared)
        let window = CovHNftViews.host(controller)
        defer { window.isHidden = true }
        let collection = controller.rootView.collectionView
        let chain = CovHNftFixtures.chain()

        XCTAssertEqual(output.calls.first, "load")
        XCTAssertEqual(controller.numberOfSections(in: collection), 2)
        XCTAssertEqual(controller.collectionView(collection, numberOfItemsInSection: 1), 0)

        controller.didReceive(viewModel: viewModel(chain: chain, available: true))
        collection.layoutIfNeeded()
        XCTAssertEqual(controller.rootView.navigationTitleLabel.text, "Collection title")
        XCTAssertEqual(controller.numberOfSections(in: collection), 3)
        XCTAssertEqual(controller.collectionView(collection, numberOfItemsInSection: 0), 1)
        XCTAssertEqual(controller.collectionView(collection, numberOfItemsInSection: 1), 2)
        XCTAssertEqual(controller.collectionView(collection, numberOfItemsInSection: 2), 1)
        XCTAssertEqual(controller.collectionView(collection, numberOfItemsInSection: 3), 0)

        let layout = collection.collectionViewLayout
        let headerSize = controller.collectionView(collection, layout: layout, sizeForItemAt: IndexPath(item: 0, section: 0))
        XCTAssertGreaterThan(headerSize.height, headerSize.width)
        XCTAssertEqual(controller.collectionView(collection, layout: layout, sizeForItemAt: IndexPath(item: 0, section: 1)).height, 249)
        XCTAssertEqual(controller.collectionView(collection, layout: layout, referenceSizeForHeaderInSection: 0), .zero)
        XCTAssertEqual(controller.collectionView(collection, layout: layout, referenceSizeForHeaderInSection: 1).height, 44)
        XCTAssertTrue(
            controller.collectionView(collection, viewForSupplementaryElementOfKind: UICollectionView.elementKindSectionFooter, at: IndexPath(item: 0, section: 1))
                .isMember(of: UICollectionReusableView.self)
        )

        let headerCell = try XCTUnwrap(collection.visibleCells.compactMap { $0 as? NftHeaderCell }.first)
        XCTAssertEqual(headerCell.titleLabel.text, "A collection description that is long enough to wrap onto a second line of text.")
        let ownedCell = try XCTUnwrap(collection.visibleCells.compactMap { $0 as? NftCell }.first { $0.nameLabel.text == "Owned 1" })
        XCTAssertEqual(ownedCell.button.imageWithTitleView?.title, R.string.localizable.commonActionSend(preferredLanguages: locale.rLanguages))
        ownedCell.button.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.actions.first?.1, .owned)
        XCTAssertEqual(output.actions.first?.0.title, "Owned 1")

        var headerTexts = Set(collection.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader).flatMap { CovHNftViews.texts(in: $0) })
        let bottom = max(0, collection.contentSize.height - collection.bounds.height)
        collection.setContentOffset(CGPoint(x: 0, y: bottom), animated: false)
        controller.scrollViewDidScroll(collection)
        collection.layoutIfNeeded()
        headerTexts.formUnion(collection.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader).flatMap { CovHNftViews.texts(in: $0) })
        let languages = controller.selectedLocale.rLanguages
        XCTAssertTrue(headerTexts.contains(R.string.localizable.nftCollectionMyNfts(preferredLanguages: languages)))
        XCTAssertTrue(headerTexts.contains(R.string.localizable.nftCollectionAvailableNfts("Collection title", preferredLanguages: languages)))
        XCTAssertTrue(output.calls.contains("next"))
        XCTAssertTrue(collection.bounces)
        XCTAssertTrue(collection.showsVerticalScrollIndicator)

        controller.collectionView(collection, didSelectItemAt: IndexPath(item: 0, section: 0))
        controller.collectionView(collection, didSelectItemAt: IndexPath(item: 1, section: 1))
        controller.collectionView(collection, didSelectItemAt: IndexPath(item: 0, section: 2))
        controller.collectionView(collection, didSelectItemAt: IndexPath(item: 9, section: 1))
        controller.collectionView(collection, didSelectItemAt: IndexPath(item: 9, section: 2))
        controller.collectionView(collection, didSelectItemAt: IndexPath(item: 0, section: 4))
        XCTAssertEqual(output.selected.map(\.0.title), ["Owned 2", "Free 3"])
        XCTAssertEqual(output.selected.map(\.1), [.owned, .available])

        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)
        controller.applyLocalization()
        XCTAssertTrue(output.calls.contains("back"))
    }

    func testAppearanceAsksForData() {
        let output = CovHNftCollectionViewOutputSpy()
        let controller = NftCollectionViewController(output: output, localizationManager: LocalizationManager.shared)
        controller.loadViewIfNeeded()
        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
        XCTAssertEqual(output.calls, ["load", "appeared"])
    }

    func testCellsBindButtonsAndImages() {
        let chain = CovHNftFixtures.chain()
        let output = CovHNftCollectionViewOutputSpy()
        let cell = NftCell(frame: CGRect(x: 0, y: 0, width: 170, height: 249))
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        XCTAssertEqual(cell.contentView.layer.cornerRadius, 12)
        cell.delegate = output

        cell.didTapButton()
        XCTAssertTrue(output.actions.isEmpty, "nothing is bound yet")

        let nft = CovHNftFixtures.nft(chain: chain, title: "Shared")
        cell.bind(cellModel: cellModel(nft, type: .available))
        XCTAssertEqual(cell.nameLabel.text, "Shared")
        XCTAssertEqual(cell.descriptionLabel.text, "Token description")
        XCTAssertNotNil(cell.imageView.image)
        XCTAssertEqual(cell.button.imageWithTitleView?.title, R.string.localizable.commonShare(preferredLanguages: locale.rLanguages))
        cell.didTapButton()
        XCTAssertEqual(output.actions.first?.1, .available)

        cell.bind(cellModel: cellModel(nft, type: .owned, image: RemoteImageViewModel(url: URL(string: CovHNftFixtures.thumbnailMissingFile)!)))
        XCTAssertEqual(cell.button.imageWithTitleView?.title, R.string.localizable.commonActionSend(preferredLanguages: locale.rLanguages))

        let header = NftHeaderCell(frame: CGRect(x: 0, y: 0, width: 300, height: 340))
        let image = UIImage()
        header.bind(cellModel: NftHeaderCellViewModel(imageViewModel: BundleImageViewModel(image: image), title: "Header"))
        XCTAssertTrue(header.imageView.image === image)
        XCTAssertEqual(header.titleLabel.text, "Header")
        header.bind(cellModel: NftHeaderCellViewModel(imageViewModel: nil, title: nil))
        XCTAssertNotNil(header.imageView.image)
        XCTAssertFalse(header.imageView.image === image)
        XCTAssertNil(header.titleLabel.text)

        let layout = NftCollectionViewLayout(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        layout.bind(viewModel: NftCollectionViewModel(
            collectionName: "Bound", collectionImage: nil, collectionDescription: nil, ownedCellModels: [], availableCellModels: []
        ))
        XCTAssertEqual(layout.navigationTitleLabel.text, "Bound")
        XCTAssertEqual((layout.collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset.left, UIConstants.bigOffset)
    }
}
