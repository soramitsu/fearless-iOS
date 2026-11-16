import XCTest
import SSFModels
import SoraFoundation
import BigInt
@testable import fearless

final class CovCPJChoosePoolOutputDouble: StakingPoolJoinChoosePoolViewOutput {
    private(set) var loadedView: StakingPoolJoinChoosePoolViewInput?
    private(set) var actions: [String] = []

    func didLoad(view: StakingPoolJoinChoosePoolViewInput) { loadedView = view }
    func didTapBackButton() { actions.append("back") }
    func didTapContinueButton() { actions.append("continue") }
    func didTapOptionsButton() { actions.append("options") }
}

final class CovCPJChoosePoolCellDelegateDouble: StakingPoolListTableCellModelDelegate {
    private(set) var infoPoolIds: [String] = []
    private(set) var selectedPoolIds: [String] = []

    func showPoolInfo(poolId: String) { infoPoolIds.append(poolId) }
    func selectPool(poolId: String) { selectedPoolIds.append(poolId) }
}

final class CovCPJChoosePoolViewTests: XCTestCase {
    private let languages = CovCPJFixtures.languages

    private func cellModel(
        id: String,
        selected: Bool,
        delegate: StakingPoolListTableCellModelDelegate? = nil
    ) -> StakingPoolListTableCellModel {
        StakingPoolListTableCellModel(
            isSelected: selected,
            poolName: "Pool \(id)",
            membersCountString: "\(id) members",
            stakedAmountAttributedString: NSAttributedString(string: "Staked \(id) DOT"),
            poolId: id,
            delegate: delegate
        )
    }

    private func makeFactory(chainAsset: ChainAsset) -> StakingPoolJoinChoosePoolViewModelFactory {
        StakingPoolJoinChoosePoolViewModelFactory(
            chainAsset: chainAsset,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )
    }

    private func pools() -> [StakingPool] {
        [
            CovCPJFixtures.pool(id: "1", name: "Alpha", points: 300_000_000_000, members: 5),
            CovCPJFixtures.pool(id: "2", name: "", points: 100_000_000_000, members: 9),
            CovCPJFixtures.pool(id: "3", name: "Blocked", points: 500_000_000_000, members: 1, state: .blocked)
        ]
    }

    // MARK: - Layout

    func testLayoutLocalizesAndConfiguresSubviews() {
        let view = StakingPoolJoinChoosePoolViewLayout()
        view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        view.locale = CovCPJFixtures.locale
        view.layoutIfNeeded()

        XCTAssertEqual(
            view.continueButton.imageWithTitleView?.title,
            R.string.localizable.poolStakingChoosepoolButtonTitle(preferredLanguages: languages)
        )
        XCTAssertEqual(
            view.navigationBar.titleLabel.text,
            R.string.localizable.poolStakingChoosepoolTitle(preferredLanguages: languages)
        )
        XCTAssertEqual(view.emptyView.title, R.string.localizable.choosePoolEmptyTitle(preferredLanguages: languages))
        XCTAssertEqual(view.emptyView.text, "")
        XCTAssertTrue(view.emptyView.isHidden)
        XCTAssertNotNil(view.tableView.refreshControl)
        XCTAssertEqual(view.tableView.separatorStyle, .none)
        XCTAssertNotNil(view.optionsButton.image(for: .normal))
    }

    // MARK: - Cell

    func testCellBindsSelectedModelAndForwardsTaps() {
        let delegate = CovCPJChoosePoolCellDelegateDouble()
        let cell = StakingPoolListTableCell(style: .default, reuseIdentifier: nil)
        cell.frame = CGRect(x: 0, y: 0, width: 390, height: 77)

        cell.bind(to: cellModel(id: "7", selected: true, delegate: delegate))
        cell.layoutIfNeeded()

        XCTAssertEqual(cell.poolNameLabel.text, "Pool 7")
        XCTAssertEqual(cell.membersCountLabel.text, "7 members")
        XCTAssertEqual(cell.stakedAmountLabel.attributedText?.string, "Staked 7 DOT")
        XCTAssertEqual(cell.selectionIconImageView.image, R.image.iconListSelectionOn())
        XCTAssertEqual(cell.selectionStyle, .none)

        cell.infoButton.sendActions(for: .touchUpInside)
        cell.perform(NSSelectorFromString("cellClicked"))

        XCTAssertEqual(delegate.infoPoolIds, ["7"])
        XCTAssertEqual(delegate.selectedPoolIds, ["7"])
    }

    func testCellShowsUnselectedIcon() {
        let cell = StakingPoolListTableCell(style: .default, reuseIdentifier: nil)

        cell.bind(to: cellModel(id: "1", selected: false))

        XCTAssertEqual(cell.selectionIconImageView.image, R.image.iconListSelectionOff())
    }

    // MARK: - View model factory

    func testFactoryFiltersOpenPoolsAndSortsByMembers() {
        let chainAsset = CovCPJFixtures.chainAsset(precision: 10)
        let delegate = CovCPJChoosePoolCellDelegateDouble()

        let models = makeFactory(chainAsset: chainAsset).buildCellViewModels(
            pools: pools(),
            locale: CovCPJFixtures.locale,
            cellsDelegate: delegate,
            selectedPoolId: "2",
            sort: .numberOfMembers
        )

        XCTAssertEqual(models.map(\.poolId), ["1", "2"])
        XCTAssertEqual(models.map(\.poolName), ["Alpha", "2"])
        XCTAssertEqual(models.map(\.isSelected), [false, true])
        XCTAssertEqual(
            models.first?.membersCountString,
            R.string.localizable.poolStakingChoosepoolMembersCountTitle(5, preferredLanguages: languages)
        )
        XCTAssertTrue(models.first?.stakedAmountAttributedString.string.contains("30") ?? false)
        XCTAssertTrue(models.first?.delegate === delegate)
    }

    func testFactorySortsByTotalStakeAndHandlesNilPools() {
        let factory = makeFactory(chainAsset: CovCPJFixtures.chainAsset(precision: 10))

        let models = factory.buildCellViewModels(
            pools: pools(),
            locale: CovCPJFixtures.locale,
            cellsDelegate: nil,
            selectedPoolId: nil,
            sort: .totalStake(assetSymbol: "DOT")
        )
        let empty = factory.buildCellViewModels(
            pools: nil,
            locale: CovCPJFixtures.locale,
            cellsDelegate: nil,
            selectedPoolId: nil,
            sort: .numberOfMembers
        )

        XCTAssertEqual(models.map(\.poolId), ["2", "1"])
        XCTAssertTrue(models.allSatisfy { !$0.isSelected })
        XCTAssertTrue(empty.isEmpty)
    }

    // MARK: - View controller

    func testControllerLoadsAndForwardsButtons() throws {
        let output = CovCPJChoosePoolOutputDouble()
        let controller = StakingPoolJoinChoosePoolViewController(
            output: output,
            localizationManager: try CovCPJFixtures.localizationManager()
        )
        controller.loadViewIfNeeded()

        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)
        controller.rootView.continueButton.sendActions(for: .touchUpInside)
        controller.rootView.optionsButton.sendActions(for: .touchUpInside)

        XCTAssertTrue(output.loadedView === controller)
        XCTAssertEqual(output.actions, ["back", "continue", "options"])
        XCTAssertTrue(controller.rootView.tableView.dataSource === controller)
        XCTAssertTrue(controller.rootView.tableView.delegate === controller)
    }

    func testControllerShowsEmptyStateAndDisabledContinue() throws {
        let controller = StakingPoolJoinChoosePoolViewController(
            output: CovCPJChoosePoolOutputDouble(),
            localizationManager: try CovCPJFixtures.localizationManager()
        )
        controller.loadViewIfNeeded()

        controller.didReceive(cellViewModels: [])

        XCTAssertFalse(controller.rootView.emptyView.isHidden)
        XCTAssertEqual(controller.tableView(controller.rootView.tableView, numberOfRowsInSection: 0), 0)
        XCTAssertEqual(controller.rootView.continueButton.fwStyleRole, .neutral)
    }

    func testControllerDisplaysCellsAndSelection() throws {
        let delegate = CovCPJChoosePoolCellDelegateDouble()
        let controller = StakingPoolJoinChoosePoolViewController(
            output: CovCPJChoosePoolOutputDouble(),
            localizationManager: try CovCPJFixtures.localizationManager()
        )
        let window = CovCPJFixtures.host(controller)
        let tableView = controller.rootView.tableView

        controller.didReceive(locale: CovCPJFixtures.locale)
        controller.didReceive(cellViewModels: [
            cellModel(id: "1", selected: false, delegate: delegate),
            cellModel(id: "2", selected: true, delegate: delegate)
        ])

        XCTAssertTrue(controller.rootView.emptyView.isHidden)
        XCTAssertEqual(controller.rootView.continueButton.fwStyleRole, .other)
        XCTAssertEqual(controller.tableView(tableView, numberOfRowsInSection: 0), 2)
        XCTAssertEqual(controller.tableView(tableView, heightForRowAt: IndexPath(row: 0, section: 0)), 77)

        let indexPath = IndexPath(row: 1, section: 0)
        let cell = try XCTUnwrap(controller.tableView(tableView, cellForRowAt: indexPath) as? StakingPoolListTableCell)
        controller.tableView(tableView, willDisplay: cell, forRowAt: indexPath)
        XCTAssertEqual(cell.poolNameLabel.text, "Pool 2")
        XCTAssertEqual(cell.selectionIconImageView.image, R.image.iconListSelectionOn())

        cell.infoButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(delegate.infoPoolIds, ["2"])

        controller.tableView(tableView, willDisplay: UITableViewCell(), forRowAt: indexPath)
        controller.applyLocalization()
        XCTAssertEqual(
            controller.rootView.navigationBar.titleLabel.text,
            R.string.localizable.poolStakingChoosepoolTitle(preferredLanguages: controller.selectedLocale.rLanguages)
        )
        window.isHidden = true
    }
}
