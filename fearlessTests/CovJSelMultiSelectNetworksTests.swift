import XCTest
import UIKit
import SoraFoundation
import SSFModels
@testable import fearless

final class CovJSelMultiSelectViewSpy: MultiSelectNetworksViewInput {
    let controller = UIViewController()
    var isSetup: Bool { true }
    private(set) var received: [MultiSelectNetworksViewModel] = []

    func didReceive(viewModel: MultiSelectNetworksViewModel) {
        received.append(viewModel)
    }
}

final class CovJSelMultiSelectInteractorSpy: MultiSelectNetworksInteractorInput {
    private(set) var setupCount = 0

    func setup(with _: MultiSelectNetworksInteractorOutput) {
        setupCount += 1
    }
}

final class CovJSelMultiSelectOutputSpy: MultiSelectNetworksModuleOutput {
    private(set) var selections: [[ChainModel.Id]?] = []

    func selectedChain(ids: [ChainModel.Id]?) {
        selections.append(ids)
    }
}

final class CovJSelMultiSelectNetworksTests: XCTestCase {
    private let locale = CovJFixture.locale
    private lazy var alpha = CovJSelFixture.chain(id: "alpha", name: "Alpha", icon: UniversalWalletRegistry.bitcoinIconURL, assets: [])
    private lazy var beta = CovJSelFixture.chain(id: "beta", name: "Beta", assets: [])
    private lazy var gamma = CovJSelFixture.chain(id: "gamma", name: "Gamma", assets: [])

    private func countTitle(_ count: Int, locale: Locale? = nil) -> String {
        R.string.localizable.commonSelectedCount("\(count)", preferredLanguages: (locale ?? self.locale).rLanguages)
    }

    private func sameImage(_ lhs: UIImage?, _ rhs: UIImage?) -> Bool {
        guard let lhs, let rhs else { return false }
        return lhs === rhs || lhs.pngData() == rhs.pngData()
    }

    private func selection(_ model: MultiSelectNetworksViewModel?) -> [String] {
        (model?.cells ?? []).filter(\.isSelected).map(\.chainId)
    }

    func testFactoryBuildsCellsCountsSelectionAndFiltersBySearch() {
        let factory = MultiSelectNetworksViewModelFactoryImpl()
        let model = factory.buildViewModel(dataSource: [alpha, beta, gamma], selectedChains: ["alpha", "gamma"], searchText: nil, locale: locale)
        XCTAssertEqual(model.cells.map(\.chainName), ["Alpha", "Beta", "Gamma"])
        XCTAssertEqual(model.cells.map(\.isSelected), [true, false, true])
        XCTAssertNotNil(model.cells[0].icon)
        XCTAssertNil(model.cells[1].icon)
        XCTAssertEqual(model.selectedCountTitle, countTitle(2))
        XCTAssertFalse(model.allIsSelected)

        let searched = factory.buildViewModel(dataSource: [alpha, beta, gamma], selectedChains: ["alpha"], searchText: "ET", locale: locale)
        XCTAssertEqual(searched.cells.map(\.chainId), ["beta"])
        XCTAssertEqual(searched.selectedCountTitle, countTitle(0))
        XCTAssertFalse(searched.allIsSelected)

        let all = factory.buildViewModel(dataSource: [alpha, beta], selectedChains: ["alpha", "beta"], searchText: "", locale: locale)
        XCTAssertTrue(all.allIsSelected)
        XCTAssertFalse(factory.buildViewModel(dataSource: [alpha], selectedChains: nil, searchText: nil, locale: locale).allIsSelected)
        XCTAssertTrue(factory.buildViewModel(dataSource: [], selectedChains: nil, searchText: nil, locale: locale).allIsSelected)

        let toggled = model.cells[1].toggle()
        XCTAssertTrue(toggled.isSelected)
        XCTAssertEqual(toggled.chainId, "beta")
        XCTAssertEqual(toggled.toggle(), model.cells[1])
        let replaced = model.replace(cells: [toggled])
        XCTAssertEqual(replaced.cells, [toggled])
        XCTAssertEqual(replaced.selectedCountTitle, model.selectedCountTitle)
        XCTAssertEqual(replaced.allIsSelected, model.allIsSelected)
    }

    func testPresenterTogglesRowsKeepsSelectionAcrossSearchesAndReportsIt() throws {
        let view = CovJSelMultiSelectViewSpy()
        let interactor = CovJSelMultiSelectInteractorSpy()
        let router = CovJSelDismissSpy()
        let output = CovJSelMultiSelectOutputSpy()
        let presenter = MultiSelectNetworksPresenter(
            canSelect: true,
            dataSource: [alpha, beta, gamma],
            selectedChains: ["alpha"],
            viewModelFactory: MultiSelectNetworksViewModelFactoryImpl(),
            moduleOutput: output,
            interactor: interactor,
            router: router,
            localizationManager: try CovJSelFixture.manager()
        )
        presenter.didLoad(view: view)
        XCTAssertEqual(interactor.setupCount, 1)
        XCTAssertEqual(selection(view.received.last), ["alpha"])

        presenter.didSelectRow(at: IndexPath(row: 1, section: 0))
        XCTAssertEqual(selection(view.received.last), ["alpha", "beta"])

        presenter.searchTextDidChanged("gam")
        XCTAssertEqual(view.received.last?.cells.map(\.chainId), ["gamma"])
        presenter.didSelectRow(at: IndexPath(row: 0, section: 0))
        XCTAssertEqual(selection(view.received.last), ["gamma"])

        presenter.searchTextDidChanged("")
        XCTAssertEqual(selection(view.received.last), ["alpha", "beta", "gamma"])
        XCTAssertTrue(view.received.last?.allIsSelected == true)

        presenter.doneButtonDidTapped()
        XCTAssertEqual(output.selections.count, 1)
        XCTAssertEqual(output.selections.first ?? nil, ["alpha", "beta", "gamma"])
        XCTAssertEqual(router.dismissed.count, 1)

        presenter.selectAllDidTapped()
        XCTAssertEqual(selection(view.received.last), [])
        XCTAssertFalse(view.received.last?.allIsSelected ?? true)
        presenter.selectAllDidTapped()
        XCTAssertEqual(selection(view.received.last), ["alpha", "beta", "gamma"])
        presenter.applyLocalization()
    }

    func testReadOnlyPresenterIgnoresSelectionAndOnlyDismisses() throws {
        let view = CovJSelMultiSelectViewSpy()
        let router = CovJSelDismissSpy()
        let output = CovJSelMultiSelectOutputSpy()
        let presenter = MultiSelectNetworksPresenter(
            canSelect: false,
            dataSource: [alpha, beta],
            selectedChains: nil,
            viewModelFactory: MultiSelectNetworksViewModelFactoryImpl(),
            moduleOutput: output,
            interactor: CovJSelMultiSelectInteractorSpy(),
            router: router,
            localizationManager: try CovJSelFixture.manager()
        )
        presenter.didLoad(view: view)
        XCTAssertEqual(view.received.count, 1)
        presenter.didSelectRow(at: IndexPath(row: 0, section: 0))
        presenter.selectAllDidTapped()
        XCTAssertEqual(view.received.count, 1)
        presenter.doneButtonDidTapped()
        XCTAssertTrue(output.selections.isEmpty)
        XCTAssertEqual(router.dismissed.count, 1)
    }

    func testAssembledScreenRendersRowsTogglesSelectsAllAndShowsEmptyState() throws {
        let output = CovJSelMultiSelectOutputSpy()
        let module = try XCTUnwrap(MultiSelectNetworksAssembly.configureModule(
            canSelect: true,
            dataSource: [alpha, beta, gamma],
            selectedChains: ["alpha"],
            moduleOutput: output
        ))
        let controller = try XCTUnwrap(module.view.controller as? MultiSelectNetworksViewController)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let screenLocale = controller.selectedLocale
        controller.viewWillAppear(false)
        XCTAssertNotNil(controller.keyboardHandler)
        XCTAssertNotNil(controller.target)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(120), 0)
        controller.updateWhileKeyboardFrameChanging(.zero)

        let root = controller.rootView
        let table = root.tableView
        XCTAssertEqual(root.titleLabel.text, countTitle(1, locale: screenLocale))
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 3)
        let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) as? MultiSelectNetworksTableCell)
        controller.tableView(table, willDisplay: cell, forRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(cell.titleLabel.text, "Alpha")
        XCTAssertTrue(cell.isSelected)
        XCTAssertTrue(sameImage(cell.checkmarkImageView.image, R.image.iconCheckMark()))
        controller.tableView(table, willDisplay: UITableViewCell(), forRowAt: IndexPath(row: 1, section: 0))

        controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 0))
        XCTAssertEqual(root.titleLabel.text, countTitle(2, locale: screenLocale))

        root.selectAllButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(root.titleLabel.text, countTitle(3, locale: screenLocale))
        XCTAssertEqual(root.selectAllButton.title(for: .normal),
                       R.string.localizable.stakingCustomDeselectButtonTitle(preferredLanguages: screenLocale.rLanguages))

        root.searchTextField.onTextDidChanged?("no such network")
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 0)
        let empty = try XCTUnwrap(CovJViewFixture.descendants(EmptyView.self, in: root.container).first)
        XCTAssertEqual(empty.title, R.string.localizable.emptyViewTitle(preferredLanguages: screenLocale.rLanguages))
        root.searchTextField.onTextDidChanged?(nil)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 3)

        root.doneButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.selections.first ?? nil, ["alpha", "beta", "gamma"])

        controller.applyLocalization()
        XCTAssertEqual(root.doneButton.title(for: .normal), R.string.localizable.commonDone(preferredLanguages: screenLocale.rLanguages))
        controller.viewDidDisappear(false)
        XCTAssertNil(controller.keyboardHandler)
    }

    func testCellSwitchesCheckmarkWithSelection() {
        let cell = MultiSelectNetworksTableCell(style: .default, reuseIdentifier: nil)
        XCTAssertEqual(cell.selectionStyle, .none)
        cell.bind(viewModel: MultiSelectNetworksViewModel.CellModel(chainId: "c", chainName: "Chain", icon: CovJSelFixture.offlineIcon,
                                                                    isSelected: false))
        XCTAssertEqual(cell.titleLabel.text, "Chain")
        XCTAssertFalse(cell.isSelected)
        XCTAssertTrue(sameImage(cell.checkmarkImageView.image, R.image.iconListSelectionOff()))
        cell.isSelected = true
        XCTAssertTrue(sameImage(cell.checkmarkImageView.image, R.image.iconCheckMark()))
        XCTAssertTrue(CovJWait.until { cell.iconImageView.image != nil })
        cell.prepareForReuse()
        XCTAssertEqual(cell.titleLabel.text, "Chain")
    }

    func testInteractorAndRouterAreTrivial() {
        let interactor = MultiSelectNetworksInteractor()
        let presenter = MultiSelectNetworksPresenter(
            canSelect: true, dataSource: [], selectedChains: nil, viewModelFactory: MultiSelectNetworksViewModelFactoryImpl(),
            moduleOutput: nil, interactor: interactor, router: MultiSelectNetworksRouter(), localizationManager: LocalizationManager.shared
        )
        let view = CovJSelMultiSelectViewSpy()
        presenter.didLoad(view: view)
        XCTAssertEqual(view.received.first?.cells.count, 0)
        presenter.doneButtonDidTapped()
        XCTAssertEqual(view.received.count, 1)
    }
}
