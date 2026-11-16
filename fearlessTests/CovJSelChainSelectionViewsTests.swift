import XCTest
import UIKit
import SoraFoundation
import SSFModels
@testable import fearless

final class CovJSelChainListPresenterSpy: ChainSelectionPresenterProtocol {
    var items: [SelectableViewModelProtocol]
    private(set) var setupCount = 0
    private(set) var selected: [Int] = []

    init(items: [SelectableViewModelProtocol]) {
        self.items = items
    }

    var numberOfItems: Int {
        items.count
    }

    func item(at index: Int) -> SelectableViewModelProtocol {
        items[index]
    }

    func selectItem(at index: Int) {
        selected.append(index)
    }

    func setup() {
        setupCount += 1
    }
}

final class CovJSelChainSelectionViewsTests: XCTestCase {
    private let first = IndexPath(row: 0, section: 0)
    private let second = IndexPath(row: 1, section: 0)

    func testChainSelectionControllerTitlesListsAndForwardsSelection() throws {
        let manager = try CovJSelFixture.manager()
        let presenter = CovJSelChainListPresenterSpy(items: [
            SelectableIconDetailsListViewModel(title: "All", subtitle: nil, icon: nil, isSelected: true, identifier: nil),
            SelectableIconDetailsListViewModel(title: "Alpha", subtitle: "1 ALPHA", icon: CovJSelFixture.offlineIcon, isSelected: false, identifier: "a")
        ])
        let controller = ChainSelectionViewController(
            nibName: R.nib.selectionListViewController.name,
            localizedTitle: LocalizableResource { locale in "Pick (\(locale.identifier))" },
            presenter: presenter,
            localizationManager: manager
        )
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }

        XCTAssertEqual(presenter.setupCount, 1)
        XCTAssertEqual(controller.title, "Pick (en)")
        XCTAssertTrue(controller.isSetup)
        XCTAssertTrue(controller.controller === controller)
        let table = try XCTUnwrap(controller.tableView)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 2)
        let allCell = try XCTUnwrap(controller.tableView(table, cellForRowAt: first) as? SelectionIconDetailsTableViewCell)
        XCTAssertEqual(allCell.titleLabel.text, "All")
        XCTAssertNotNil(allCell.iconImageView.image, "rows without an icon show the all-networks icon")
        XCTAssertFalse(allCell.checkmarkImageView.isHidden)
        let alphaCell = try XCTUnwrap(controller.tableView(table, cellForRowAt: second) as? SelectionIconDetailsTableViewCell)
        XCTAssertEqual(alphaCell.titleLabel.text, "Alpha")
        XCTAssertEqual(alphaCell.subtitleLabel.text, "1 ALPHA")
        XCTAssertTrue(alphaCell.checkmarkImageView.isHidden)

        controller.tableView(table, didSelectRowAt: second)
        XCTAssertEqual(presenter.selected, [1])

        presenter.items.removeLast()
        controller.bind(viewModel: .searchNetworkPlaceholder)
        controller.didReload()
        XCTAssertEqual(table.numberOfRows(inSection: 0), 1)
        XCTAssertNotNil(table.tableFooterView)
    }

    func testStakingChainSelectionControllerShowsPoolBadges() throws {
        let manager = try CovJSelFixture.manager()
        let chainAsset = CovJFixture.chainAsset(chainName: "Pooled", symbol: "POL")
        let presenter = CovJSelChainListPresenterSpy(items: [
            AssetSelectionTableViewCellModel(title: "Pooled", subtitle: "2", icon: nil, isSelected: false, stakingType: .normal(chainAsset: chainAsset)),
            AssetSelectionTableViewCellModel(title: "Pooled", subtitle: "2", icon: nil, isSelected: true, stakingType: .pool(chainAsset: chainAsset))
        ])
        let controller = StakingChainSelectionViewController(
            nibName: R.nib.selectionListViewController.name,
            localizedTitle: LocalizableResource { _ in "Stake" },
            presenter: presenter,
            localizationManager: manager
        )
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }

        XCTAssertEqual(presenter.setupCount, 1)
        XCTAssertEqual(controller.title, "Stake")
        let table = try XCTUnwrap(controller.tableView)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 2)
        let direct = try XCTUnwrap(controller.tableView(table, cellForRowAt: first) as? AssetSelectionTableViewCell)
        XCTAssertTrue(direct.stakingTypeLabel.isHidden)
        XCTAssertTrue(direct.checkmarkImageView.isHidden)
        let pool = try XCTUnwrap(controller.tableView(table, cellForRowAt: second) as? AssetSelectionTableViewCell)
        XCTAssertEqual(pool.stakingTypeLabel.text, "POOL")
        XCTAssertFalse(pool.stakingTypeLabel.isHidden)
        XCTAssertFalse(pool.checkmarkImageView.isHidden)
        controller.tableView(table, didSelectRowAt: second)
        XCTAssertEqual(presenter.selected, [1])
    }

    func testAssetSelectionCellBindsFollowsSelectionAndStopsAfterReuse() throws {
        let cell = AssetSelectionTableViewCell(style: .default, reuseIdentifier: nil)
        cell.frame = CGRect(x: 0, y: 0, width: 390, height: 56)
        cell.layoutIfNeeded()
        XCTAssertEqual(cell.backgroundColor, .clear)
        XCTAssertNotNil(cell.selectedBackgroundView)

        let model = AssetSelectionTableViewCellModel(
            title: "Kusama",
            subtitle: "3.5 KSM",
            icon: nil,
            isSelected: true,
            stakingType: .pool(chainAsset: nil)
        )
        cell.bind(viewModel: model)
        XCTAssertEqual(cell.titleLabel.text, "Kusama")
        XCTAssertEqual(cell.subtitleLabel.text, "3.5 KSM")
        XCTAssertEqual(cell.stakingTypeLabel.text, "POOL")
        XCTAssertFalse(cell.stakingTypeLabel.isHidden)
        XCTAssertNotNil(cell.iconImageView.image)
        XCTAssertFalse(cell.checkmarkImageView.isHidden)

        model.isSelected = false
        XCTAssertTrue(cell.checkmarkImageView.isHidden, "the cell observes selection changes")
        model.isSelected = true
        XCTAssertFalse(cell.checkmarkImageView.isHidden)

        let other = SelectableIconDetailsListViewModel(title: "Other", subtitle: nil, icon: nil, isSelected: false, identifier: nil)
        cell.bind(viewModel: other)
        XCTAssertEqual(cell.titleLabel.text, "Kusama", "other view models are ignored")

        cell.prepareForReuse()
        model.isSelected = false
        XCTAssertFalse(cell.checkmarkImageView.isHidden, "a reused cell no longer follows the old model")

        let remote = AssetSelectionTableViewCellModel(
            title: "Bitcoin",
            subtitle: nil,
            icon: CovJSelFixture.offlineIcon,
            isSelected: false,
            stakingType: .normal(chainAsset: nil)
        )
        cell.bind(viewModel: remote)
        XCTAssertEqual(cell.titleLabel.text, "Bitcoin")
        XCTAssertNil(cell.subtitleLabel.text)
        XCTAssertTrue(cell.stakingTypeLabel.isHidden)
        XCTAssertTrue(cell.checkmarkImageView.isHidden)
        XCTAssertTrue(CovJWait.until { cell.iconImageView.image != nil })
    }
}
