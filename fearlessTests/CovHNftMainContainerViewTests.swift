import SoraFoundation
import SoraUI
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class CovHNftMainViewOutputSpy: MainNftContainerViewOutput {
    private(set) var calls: [String] = []
    private(set) var selected: [NFTCollection] = []

    func didLoad(view _: MainNftContainerViewInput) { calls.append("load") }
    func didSelect(collection: NFTCollection) { selected.append(collection) }
    func didPullToRefresh() { calls.append("refresh") }
    func viewAppeared() { calls.append("appeared") }
    func didTapFilterButton() { calls.append("filter") }
    func didTapCollectionButton() { calls.append("collection") }
    func didTapTableButton() { calls.append("table") }
}

enum CovHNftCellModels {
    static func sections(chain: ChainModel, count: Int, image: ImageViewModelProtocol? = nil) -> [NftNetworkSectionModel] {
        let items = (0 ..< count).map { index -> NftListCellModel in
            let collection = CovHNftFixtures.collection(chain: chain, address: "0x\(index)", name: "Collection \(index)")
            return NftListCellModel(
                identity: NftCollectionIdentity(ecosystem: "substrate", chainId: chain.chainId, collectionId: "0x\(index)"),
                imageViewModel: image,
                chainNameLabelText: chain.name,
                collection: collection,
                currentCount: 2,
                availableCount: 10,
                locale: Locale(identifier: "en")
            )
        }
        return [NftNetworkSectionModel(chainId: chain.chainId, networkTitle: "Network · Substrate", items: items)]
    }

    static func item(chain: ChainModel, image: ImageViewModelProtocol?, counts: Bool) -> NftListCellModel {
        NftListCellModel(
            identity: NftCollectionIdentity(ecosystem: "substrate", chainId: chain.chainId, collectionId: "0xitem"),
            imageViewModel: image,
            chainNameLabelText: "Chain label",
            collection: CovHNftFixtures.collection(chain: chain, name: "Item collection"),
            currentCount: counts ? 3 : nil,
            availableCount: counts ? 7 : nil,
            locale: Locale(identifier: "en")
        )
    }
}

final class CovHNftMainContainerViewControllerTests: XCTestCase {
    private func makeController() -> (MainNftContainerViewController, CovHNftMainViewOutputSpy, UIWindow) {
        let output = CovHNftMainViewOutputSpy()
        let controller = MainNftContainerViewController(output: output, localizationManager: LocalizationManager.shared)
        let window = CovHNftViews.host(controller)
        return (controller, output, window)
    }

    func testLoadingRegistersOutputAndButtonsForwardTaps() {
        let output = CovHNftMainViewOutputSpy()
        let controller = MainNftContainerViewController(output: output, localizationManager: LocalizationManager.shared)
        controller.loadViewIfNeeded()
        let root = controller.rootView

        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
        root.nftContentControl.filterButton.sendActions(for: .touchUpInside)
        root.nftContentControl.tableButton.sendActions(for: .touchUpInside)
        XCTAssertFalse(root.tableView.isHidden)
        XCTAssertTrue(root.collectionView.isHidden)
        root.nftContentControl.collectionButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(root.tableView.isHidden)
        XCTAssertFalse(root.collectionView.isHidden)
        root.tableView.refreshControl?.sendActions(for: .valueChanged)
        root.collectionView.refreshControl?.sendActions(for: .valueChanged)
        controller.applyLocalization()

        XCTAssertEqual(output.calls, ["load", "appeared", "filter", "table", "collection", "refresh", "refresh"])
    }

    func testSkeletonRowsBeforeDataAndRealRowsAfter() throws {
        let (controller, output, window) = makeController()
        defer { window.isHidden = true }
        let root = controller.rootView
        let table = root.tableView
        let collection = root.collectionView

        XCTAssertEqual(controller.numberOfSections(in: table), 1)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 10)
        XCTAssertEqual(controller.numberOfSections(in: collection), 1)
        XCTAssertEqual(controller.collectionView(collection, numberOfItemsInSection: 0), 10)
        XCTAssertNil(controller.tableView(table, titleForHeaderInSection: 0))
        XCTAssertEqual(controller.collectionView(collection, layout: collection.collectionViewLayout, referenceSizeForHeaderInSection: 0), .zero)
        XCTAssertFalse(controller.shouldDisplayEmptyState)

        root.bind(appearance: .table)
        table.reloadData()
        table.layoutIfNeeded()
        XCTAssertFalse(table.visibleCells.isEmpty)

        let chain = CovHNftFixtures.chain()
        let image = UIImage()
        controller.didReceive(viewModels: CovHNftCellModels.sections(chain: chain, count: 3, image: BundleImageViewModel(image: image)))
        table.layoutIfNeeded()
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 3)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 5), 0)
        XCTAssertEqual(controller.tableView(table, titleForHeaderInSection: 0), "Network · Substrate")
        let listCell = try XCTUnwrap(table.visibleCells.compactMap { $0 as? NftListCell }.first)
        XCTAssertEqual(listCell.chainLabel.text, chain.name)
        XCTAssertTrue(listCell.collectionNameLabel.text?.hasPrefix("Collection") == true)

        controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 0))
        controller.tableView(table, didSelectRowAt: IndexPath(row: 9, section: 0))
        XCTAssertEqual(output.selected.map(\.name), ["Collection 1"])

        root.bind(appearance: .collection)
        collection.reloadData()
        collection.layoutIfNeeded()
        let size = controller.collectionView(collection, layout: collection.collectionViewLayout, sizeForItemAt: IndexPath(item: 0, section: 0))
        XCTAssertEqual(size.height, 233)
        XCTAssertGreaterThan(size.width, 0)
        XCTAssertEqual(
            controller.collectionView(collection, layout: collection.collectionViewLayout, referenceSizeForHeaderInSection: 0),
            CGSize(width: 1, height: 38)
        )
        let collectionCell = try XCTUnwrap(collection.visibleCells.compactMap { $0 as? NftCollectionCell }.first)
        XCTAssertEqual(collectionCell.nftCountLabel.text, "2/10")
        XCTAssertTrue(collectionCell.imageView.image === image)
        let headers = collection.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader)
        XCTAssertTrue(headers.contains { CovHNftViews.texts(in: $0).contains("Network · Substrate") })
        XCTAssertTrue(
            controller.collectionView(collection, viewForSupplementaryElementOfKind: UICollectionView.elementKindSectionFooter, at: IndexPath(item: 0, section: 0))
                .isMember(of: UICollectionReusableView.self)
        )

        controller.collectionView(collection, didSelectItemAt: IndexPath(item: 2, section: 0))
        controller.collectionView(collection, didSelectItemAt: IndexPath(item: 7, section: 0))
        XCTAssertEqual(output.selected.map(\.name), ["Collection 1", "Collection 2"])
    }

    func testEmptyResultShowsEmptyStateAndRefreshClearsIt() {
        let controller = MainNftContainerViewController(output: CovHNftMainViewOutputSpy(), localizationManager: LocalizationManager.shared)
        controller.loadViewIfNeeded()
        let root = controller.rootView

        controller.didReceive(viewModels: [])
        XCTAssertTrue(controller.shouldDisplayEmptyState)
        XCTAssertTrue(root.emptyViewContainer.subviews.contains { $0 is EmptyView })
        XCTAssertTrue(controller.contentViewForEmptyState === root.emptyViewContainer)
        let emptyView = controller.viewForEmptyState as? EmptyView
        XCTAssertNotNil(emptyView)
        XCTAssertEqual(controller.numberOfSections(in: root.tableView), 0)

        root.tableView.refreshControl?.sendActions(for: .valueChanged)
        XCTAssertEqual(controller.numberOfSections(in: root.tableView), 1)
        XCTAssertFalse(controller.shouldDisplayEmptyState)
    }

    func testAppearanceFromPresenterSwitchesLayout() {
        let (controller, _, window) = makeController()
        defer { window.isHidden = true }
        controller.didReceive(appearance: .table)
        XCTAssertFalse(controller.rootView.tableView.isHidden)
        XCTAssertEqual(controller.rootView.nftContentControl.tableButton.alpha, 1)
        XCTAssertEqual(controller.rootView.nftContentControl.collectionButton.alpha, 0.3, accuracy: 0.001)
        controller.didReceive(appearance: .collection)
        XCTAssertTrue(controller.rootView.tableView.isHidden)
        XCTAssertTrue(controller.rootView.nftContentControl.tableButton.isUserInteractionEnabled)
        XCTAssertFalse(controller.rootView.nftContentControl.collectionButton.isUserInteractionEnabled)
    }
}

final class CovHNftMainContainerCellTests: XCTestCase {
    func testListCellSkeletonAndBinding() {
        let cell = NftListCell(style: .default, reuseIdentifier: nil)
        cell.frame = CGRect(x: 0, y: 0, width: 390, height: 104)
        cell.layoutIfNeeded()
        let chain = CovHNftFixtures.chain()

        cell.bind(viewModel: nil)
        XCTAssertEqual(cell.chainLabel.alpha, 0)
        XCTAssertEqual(cell.nftCountLabel.alpha, 0)
        cell.didAppearSkeleton()
        cell.didDisappearSkeleton()
        cell.frame = CGRect(x: 0, y: 0, width: 320, height: 104)
        cell.didUpdateSkeletonLayout()
        cell.startLoadingIfNeeded()
        XCTAssertEqual(cell.collectionNameLabel.alpha, 0)

        let image = UIImage()
        cell.bind(viewModel: CovHNftCellModels.item(chain: chain, image: BundleImageViewModel(image: image), counts: true))
        XCTAssertEqual(cell.chainLabel.alpha, 1)
        XCTAssertEqual(cell.chainLabel.text, "Chain label")
        XCTAssertEqual(cell.collectionNameLabel.text, "Item collection")
        XCTAssertFalse(cell.nftCountLabel.isHidden)
        XCTAssertEqual(
            cell.nftCountLabel.text,
            R.string.localizable.nftsCollectionCount(3, 7, preferredLanguages: Locale(identifier: "en").rLanguages)
        )
        XCTAssertTrue(cell.nftImageView.image === image)

        cell.bind(viewModel: CovHNftCellModels.item(chain: chain, image: nil, counts: false))
        XCTAssertTrue(cell.nftCountLabel.isHidden)
        XCTAssertNotNil(cell.nftImageView.image)
        XCTAssertFalse(cell.nftImageView.image === image)
        cell.didUpdateSkeletonLayout()
        cell.stopLoadingIfNeeded()

        cell.prepareForReuse()
        XCTAssertNil(cell.nftImageView.image)
    }

    func testListCellSkeletonWithZeroFrame() {
        let cell = NftListCell(style: .default, reuseIdentifier: nil)
        cell.frame = .zero
        cell.bind(viewModel: nil)
        XCTAssertEqual(cell.nftImageView.alpha, 0)
        cell.chainLabel.text = "measured"
        cell.frame = CGRect(x: 0, y: 0, width: 300, height: 100)
        cell.didUpdateSkeletonLayout()
        cell.stopLoadingIfNeeded()
        XCTAssertEqual(cell.nftImageView.alpha, 1)
    }

    func testCollectionCellSkeletonAndBinding() {
        let cell = NftCollectionCell(frame: CGRect(x: 0, y: 0, width: 180, height: 233))
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        XCTAssertEqual(cell.contentView.layer.cornerRadius, 12)
        let chain = CovHNftFixtures.chain(name: "Collection chain")

        cell.bind(cellModel: nil)
        XCTAssertEqual(cell.chainNameLabel.alpha, 0)
        cell.didAppearSkeleton()
        cell.didDisappearSkeleton()
        cell.frame = CGRect(x: 0, y: 0, width: 170, height: 233)
        cell.didUpdateSkeletonLayout()

        let image = UIImage()
        cell.bind(cellModel: CovHNftCellModels.item(chain: chain, image: BundleImageViewModel(image: image), counts: true))
        XCTAssertEqual(cell.chainNameLabel.alpha, 1)
        XCTAssertEqual(cell.nftCountLabel.text, "3/7")
        XCTAssertFalse(cell.nftCountLabel.isHidden)
        XCTAssertEqual(cell.chainNameLabel.text, "Collection chain")
        XCTAssertEqual(cell.collectionNameLabel.text, "Item collection")
        XCTAssertTrue(cell.imageView.image === image)

        cell.bind(cellModel: CovHNftCellModels.item(chain: chain, image: nil, counts: false))
        XCTAssertTrue(cell.nftCountLabel.isHidden)
        XCTAssertNotNil(cell.imageView.image)
        XCTAssertFalse(cell.imageView.image === image)

        let zeroCell = NftCollectionCell(frame: .zero)
        zeroCell.bind(cellModel: nil)
        XCTAssertEqual(zeroCell.imageView.alpha, 0)
        zeroCell.didUpdateSkeletonLayout()
        XCTAssertEqual(zeroCell.imageView.alpha, 0)
    }

    func testContentControlAndHeader() {
        let control = NFTContentControl()
        control.apply(state: .table)
        XCTAssertEqual(control.tableButton.alpha, 1)
        XCTAssertFalse(control.tableButton.isUserInteractionEnabled)
        XCTAssertTrue(control.collectionButton.isUserInteractionEnabled)
        control.apply(state: .collection)
        XCTAssertEqual(control.collectionButton.alpha, 1)
        XCTAssertFalse(control.collectionButton.isUserInteractionEnabled)

        let header = NftNetworkCollectionHeader(frame: CGRect(x: 0, y: 0, width: 300, height: 38))
        header.bind(title: "Header title")
        XCTAssertEqual(CovHNftViews.texts(in: header), ["Header title"])
        XCTAssertEqual(NftNetworkCollectionHeader.reuseID, "NftNetworkCollectionHeader")

        let layout = MainNftContainerViewLayout(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        XCTAssertTrue(layout.tableView.isHidden)
        layout.bind(appearance: .table)
        XCTAssertTrue(layout.collectionView.isHidden)
        XCTAssertNotNil(layout.tableView.refreshControl)
    }
}
