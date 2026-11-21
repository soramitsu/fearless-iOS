import XCTest
import UIKit
import SoraFoundation
import SSFModels
@testable import fearless

final class CovJNetManagmentViewOutputSpy: NetworkManagmentViewOutput {
    var loads = 0
    var searches: [String?] = []
    var selectedRows: [IndexPath] = []
    var filters: [String] = []
    var backs = 0
    var favouriteTaps: [IndexPath?] = []

    func didLoad(view _: NetworkManagmentViewInput) { loads += 1 }
    func searchTextDidChanged(_ text: String?) { searches.append(text) }
    func didSelectRow(at indexPath: IndexPath) { selectedRows.append(indexPath) }
    func didSelectAllFilter() { filters.append("all") }
    func didSelectPopularFilter() { filters.append("popular") }
    func didSelectFavouriteFilter() { filters.append("favourite") }
    func didTapBackButton() { backs += 1 }
    func didTappedFavouriteButton(at indexPath: IndexPath?) { favouriteTaps.append(indexPath) }
}

final class CovJNetManagmentAssemblyOutput: NetworkManagmentModuleOutput {
    var selections: [String] = []
    func did(select: NetworkManagmentFilter, contextTag _: Int?) { selections.append(select.identifier) }
}

final class CovJNetManagmentViewTests: XCTestCase {
    private func cells() -> [NetworkManagmentCellViewModel] {
        [
            NetworkManagmentCellViewModel(
                icon: BundleImageViewModel(image: R.image.iconNetwotkManagmentAll()),
                name: "All networks",
                isSelected: true,
                isFavourite: nil,
                networkSelectType: .all
            ),
            NetworkManagmentCellViewModel(icon: nil, name: "Alpha", isSelected: false, isFavourite: true, networkSelectType: .chain("alpha")),
            NetworkManagmentCellViewModel(icon: nil, name: "Beta", isSelected: false, isFavourite: false, networkSelectType: .chain("beta"))
        ]
    }

    private func makeController() throws -> (NetworkManagmentViewController, CovJNetManagmentViewOutputSpy, UIWindow) {
        let output = CovJNetManagmentViewOutputSpy()
        let controller = NetworkManagmentViewController(output: output, localizationManager: LocalizationManager.shared)
        let window = try CovJViewFixture.host(controller)
        return (controller, output, window)
    }

    func testControlsForwardToOutput() throws {
        let (controller, output, window) = try makeController()
        defer { window.isHidden = true }
        let root = controller.rootView

        XCTAssertEqual(output.loads, 1)
        XCTAssertEqual(root.tableView.separatorStyle, .none)
        XCTAssertTrue(root.tableView.dataSource === controller)
        XCTAssertTrue(root.tableView.delegate === controller)

        root.navigationBar.backButton.sendActions(for: .touchUpInside)
        root.allFilterButton.sendActions(for: .touchUpInside)
        root.popularFilterButton.sendActions(for: .touchUpInside)
        root.favouriteFilterButton.sendActions(for: .touchUpInside)
        root.searchTextField.textField.text = "alp"
        root.searchTextField.textFieldDidChange()

        XCTAssertEqual(output.backs, 1)
        XCTAssertEqual(output.filters, ["all", "popular", "favourite"])
        XCTAssertEqual(output.searches, ["alp"])
    }

    func testRowsBindCellsAndRouteSelectionAndFavourites() throws {
        let (controller, output, window) = try makeController()
        defer { window.isHidden = true }
        let root = controller.rootView
        let table = root.tableView

        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 0)
        controller.didReceive(viewModel: NetworkManagmentViewModel(activeFilter: .popular, cells: cells()))

        XCTAssertTrue(root.popularFilterButton.isSelected)
        XCTAssertFalse(root.allFilterButton.isSelected)
        XCTAssertFalse(controller.shouldDisplayEmptyState)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 3)

        let dequeued = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 2, section: 0)) as? NetworkManagmentTableCell)
        controller.tableView(table, willDisplay: dequeued, forRowAt: IndexPath(row: 2, section: 0))
        XCTAssertEqual(dequeued.titleLabel.text, "Beta")
        XCTAssertTrue(dequeued.delegate === output)
        controller.tableView(table, willDisplay: dequeued, forRowAt: IndexPath(row: 9, section: 0))
        XCTAssertEqual(dequeued.titleLabel.text, "Beta")

        table.layoutIfNeeded()
        let visible = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 1, section: 0)) as? NetworkManagmentTableCell)
        XCTAssertEqual(visible.titleLabel.text, "Alpha")
        visible.favouriteButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.favouriteTaps, [IndexPath(row: 1, section: 0)])

        controller.tableView(table, didSelectRowAt: IndexPath(row: 2, section: 0))
        XCTAssertEqual(output.selectedRows, [IndexPath(row: 2, section: 0)])
    }

    func testEmptyListShowsSearchEmptyState() throws {
        let (controller, _, window) = try makeController()
        defer { window.isHidden = true }
        let root = controller.rootView
        let languages = controller.selectedLocale.rLanguages

        controller.didReceive(viewModel: NetworkManagmentViewModel(activeFilter: .favourite, cells: []))

        XCTAssertTrue(root.favouriteFilterButton.isSelected)
        XCTAssertTrue(controller.shouldDisplayEmptyState)
        XCTAssertTrue(controller.contentViewForEmptyState === root.container)
        let empty = try XCTUnwrap(CovJViewFixture.descendants(EmptyView.self, in: root.container).first)
        XCTAssertEqual(empty.title, R.string.localizable.emptyViewTitle(preferredLanguages: languages))
        XCTAssertEqual(empty.text, R.string.localizable.selectNetworkSearchEmptySubtitle(preferredLanguages: languages))
        XCTAssertEqual(empty.iconMode, .bigFilledShadow)
        XCTAssertNotNil(empty.image)

        controller.didReceive(viewModel: NetworkManagmentViewModel(activeFilter: .chain("alpha"), cells: cells()))
        XCTAssertFalse(controller.shouldDisplayEmptyState)
        XCTAssertTrue(root.allFilterButton.isSelected)
    }

    func testLocalizationAndKeyboardAdjustTheList() throws {
        let (controller, _, window) = try makeController()
        defer { window.isHidden = true }
        let root = controller.rootView
        let languages = controller.selectedLocale.rLanguages

        controller.applyLocalization()
        XCTAssertEqual(root.searchTextField.textField.placeholder, R.string.localizable.commonSearch(preferredLanguages: languages))
        XCTAssertEqual(
            root.popularFilterButton.imageWithTitleView?.title,
            R.string.localizable.networkManagementPopular(preferredLanguages: languages).uppercased()
        )

        controller.viewWillAppear(false)
        XCTAssertTrue(controller.target === root.keyboardAdoptableConstraint)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(120), 0)

        root.layoutIfNeeded()
        let bottom = root.container.frame.maxY
        controller.apply(keyboardFrame: CGRect(x: 0, y: 544, width: 390, height: 300), keyboardHidden: false)
        XCTAssertEqual(root.container.frame.maxY, bottom - 300, accuracy: 0.5)
        controller.apply(keyboardFrame: CGRect(x: 0, y: 544, width: 390, height: 300), keyboardHidden: true)
        XCTAssertEqual(root.container.frame.maxY, bottom, accuracy: 0.5)

        controller.viewDidDisappear(false)
        XCTAssertNil(controller.keyboardHandler)
    }

    func testCellShowsSelectionFavouriteStateAndForwardsStarTap() {
        let cell = NetworkManagmentTableCell(style: .default, reuseIdentifier: nil)
        XCTAssertEqual(cell.selectionStyle, .none)

        cell.bind(viewModel: cells()[0])
        XCTAssertEqual(cell.titleLabel.text, "All networks")
        XCTAssertTrue(cell.favouriteButton.isHidden)
        XCTAssertFalse(cell.checkmarkImageView.isHidden)
        XCTAssertNotNil(cell.checkmarkImageView.image)
        XCTAssertNotNil(cell.iconImageView.image)

        cell.bind(viewModel: cells()[1])
        XCTAssertEqual(cell.titleLabel.text, "Alpha")
        XCTAssertFalse(cell.favouriteButton.isHidden)
        XCTAssertEqual(cell.favouriteButton.tintColor, R.color.colorPink())

        cell.bind(viewModel: cells()[2])
        XCTAssertEqual(cell.favouriteButton.tintColor, R.color.colorWhite16())

        cell.prepareForReuse()
        let delegate = CovJNetManagmentViewOutputSpy()
        cell.delegate = delegate
        cell.favouriteButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(delegate.favouriteTaps, [nil])
    }

    func testAssemblyBuildsAModuleThatListsTheProvidedChains() throws {
        let output = CovJNetManagmentAssemblyOutput()
        let chains = [CovJNetFixture.chain(name: "Alpha"), CovJNetFixture.chain(name: "Beta")]
        let module = try XCTUnwrap(NetworkManagmentAssembly.configureModule(
            wallet: AccountGenerator.generateMetaAccount(),
            chains: chains,
            contextTag: 3,
            moduleOutput: output
        ))
        XCTAssertTrue(module.input is NetworkManagmentPresenter)
        let controller = try XCTUnwrap(module.view.controller as? NetworkManagmentViewController)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let table = controller.rootView.tableView

        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 3)
        XCTAssertTrue(controller.rootView.allFilterButton.isSelected)

        controller.rootView.popularFilterButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 1)
        XCTAssertTrue(controller.rootView.popularFilterButton.isSelected)
        XCTAssertTrue(output.selections.isEmpty)
    }
}
