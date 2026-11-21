import XCTest
import UIKit
import RobinHood
import SoraFoundation
import SSFModels
@testable import fearless

/// Delivers one fixed value (or failure) to every observer on the requested queue; never touches the network.
final class CovJMxSingleValueProvider<T>: SingleValueProviderProtocol {
    typealias Model = T

    let item: T?
    let failure: Error?
    let executionQueue = OperationQueue()

    init(item: T?, failure: Error?) {
        self.item = item
        self.failure = failure
    }

    func fetch(with _: ((Result<T?, Error>?) -> Void)?) -> CompoundOperationWrapper<T?> {
        let item = item
        return CompoundOperationWrapper(targetOperation: ClosureOperation<T?> { item })
    }

    func addObserver(
        _: AnyObject,
        deliverOn queue: DispatchQueue?,
        executing updateBlock: @escaping ([DataProviderChange<T>]) -> Void,
        failing failureBlock: @escaping (Error) -> Void,
        options _: DataProviderObserverOptions
    ) {
        let item = item
        let failure = failure
        (queue ?? .main).async {
            if let failure {
                failureBlock(failure)
            } else {
                updateBlock(item.map { [DataProviderChange.insert(newItem: $0)] } ?? [])
            }
        }
    }

    func removeObserver(_: AnyObject) {}
    func refresh() {}
}

final class CovJMxJsonFactory: JsonDataProviderFactoryProtocol {
    var value: Any?
    var failure: Error?
    private(set) var urls: [URL] = []

    func getJson<T: Codable & Equatable>(for url: URL) throws -> AnySingleValueProvider<T> {
        urls.append(url)
        return AnySingleValueProvider(CovJMxSingleValueProvider<T>(item: value as? T, failure: failure))
    }
}

final class CovJMxCurrencyInteractorOutput: SelectCurrencyInteractorOutput {
    var selected: [Currency] = []
    var supported: [Result<[Currency], Error>] = []
    func didRecieve(supportedСurrencies: Result<[Currency], Error>) { supported.append(supportedСurrencies) }
    func didRecieve(selectedCurrency: Currency) { selected.append(selectedCurrency) }
}

final class CovJMxCurrencyView: UIViewController, SelectCurrencyViewInput {
    var received: [[SelectCurrencyCellViewModel]] = []
    func didRecieve(viewModel: [SelectCurrencyCellViewModel]) { received.append(viewModel) }
}

final class CovJMxCurrencyInteractor: SelectCurrencyInteractorInput {
    weak var output: SelectCurrencyInteractorOutput?
    var selections: [Currency] = []
    func setup(with output: SelectCurrencyInteractorOutput) { self.output = output }
    func didSelect(_ currency: Currency) { selections.append(currency) }
}

final class CovJMxCurrencyRouter: CovJSheetSpy, SelectCurrencyRouterInput {
    var proceeds = 0
    var backs = 0
    func proceed(from _: SelectCurrencyViewInput?) { proceeds += 1 }
    func back(from _: SelectCurrencyViewInput?) { backs += 1 }
}

final class CovJMxCurrencyViewOutput: SelectCurrencyViewOutput {
    var loads = 0
    var backs = 0
    var selections: [String] = []
    func didLoad(view _: SelectCurrencyViewInput) { loads += 1 }
    func didSelect(viewModel: SelectCurrencyCellViewModel) { selections.append(viewModel.id) }
    func back() { backs += 1 }
}

final class CovJMxSelectCurrencyLogicTests: XCTestCase {
    private let usd = Currency.defaultCurrency()
    private let eur = Currency.euro()

    func testInteractorReportsSelectedCurrencyAndSupportedFiats() throws {
        let factory = CovJMxJsonFactory()
        factory.value = [usd, eur]
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = makeInteractor(wallet: wallet, factory: factory)
        let output = CovJMxCurrencyInteractorOutput()

        interactor.setup(with: output)

        XCTAssertEqual(output.selected, [wallet.selectedCurrency])
        XCTAssertEqual(factory.urls, [try XCTUnwrap(ApplicationConfig.shared.fiatsURL)])
        XCTAssertTrue(CovJWait.until { output.supported.count == 1 })
        guard case let .success(currencies) = output.supported.first else {
            return XCTFail("Expected supported currencies")
        }
        XCTAssertEqual(currencies.map(\.id), ["usd", "eur"])
    }

    func testInteractorForwardsProviderFailure() {
        let factory = CovJMxJsonFactory()
        factory.failure = CovJError("fiats")
        let interactor = makeInteractor(wallet: AccountGenerator.generateMetaAccount(), factory: factory)
        let output = CovJMxCurrencyInteractorOutput()

        interactor.setup(with: output)

        XCTAssertTrue(CovJWait.until { output.supported.count == 1 })
        guard case let .failure(error) = output.supported.first else {
            return XCTFail("Expected a failure")
        }
        XCTAssertEqual(error as? CovJError, CovJError("fiats"))
    }

    func testViewModelFactoryMarksSelectionAndSkipsInvalidIcons() {
        let noIcon = Currency(id: "jpy", symbol: "¥", name: "Yen", icon: "")
        let viewModels = SelectCurrencyViewModelFactory().buildViewModel(
            supportedСurrencies: [usd, eur, noIcon],
            selectedCurrency: eur
        )

        XCTAssertEqual(viewModels.map(\.id), ["usd", "eur", "jpy"])
        XCTAssertEqual(viewModels.map(\.title), ["US Dollar", "Euro", "Yen"])
        XCTAssertEqual(viewModels.map(\.isSelected), [false, true, false])
        XCTAssertEqual(viewModels.first?.imageViewModel?.url.absoluteString, usd.icon)
        XCTAssertNil(viewModels.last?.imageViewModel)
    }

    func testPresenterWaitsForBothInputsAndSelectsKnownCurrencies() throws {
        let interactor = CovJMxCurrencyInteractor()
        let router = CovJMxCurrencyRouter()
        let view = CovJMxCurrencyView()
        let presenter = SelectCurrencyPresenter(
            interactor: interactor,
            router: router,
            viewModelFactory: SelectCurrencyViewModelFactory(),
            localizationManager: try XCTUnwrap(LocalizationManager(localization: "en"))
        )

        presenter.didLoad(view: view)
        XCTAssertTrue(interactor.output === presenter)
        presenter.didRecieve(selectedCurrency: usd)
        XCTAssertTrue(view.received.isEmpty)

        presenter.didRecieve(supportedСurrencies: .success([usd, eur]))
        XCTAssertEqual(view.received.last?.map(\.id), ["usd", "eur"])
        XCTAssertEqual(view.received.last?.map(\.isSelected), [true, false])

        let unknown = SelectCurrencyCellViewModel(imageViewModel: nil, title: "X", isSelected: true, id: "xyz")
        presenter.didSelect(viewModel: unknown)
        XCTAssertTrue(interactor.selections.isEmpty)

        presenter.didSelect(viewModel: try XCTUnwrap(view.received.last?.last))
        XCTAssertEqual(interactor.selections.map(\.id), ["eur"])
        XCTAssertEqual(interactor.selections.first?.isSelected, true)
        XCTAssertEqual(router.proceeds, 1)

        presenter.back()
        presenter.didRecieve(supportedСurrencies: .failure(CovJError("down")))
        presenter.applyLocalization()
        XCTAssertEqual(router.backs, 1)
        XCTAssertEqual(router.errors.compactMap { $0 as? CovJError }, [CovJError("down")])
        XCTAssertEqual(view.received.count, 1)
    }

    private func makeInteractor(wallet: MetaAccountModel, factory: CovJMxJsonFactory) -> SelectCurrencyInteractor {
        SelectCurrencyInteractor(
            selectedMetaAccount: wallet,
            repository: AnyDataProviderRepository(CovJMemoryRepository<MetaAccountModel>()),
            jsonDataProviderFactory: factory,
            eventCenter: EventCenter(),
            operationQueue: OperationQueue()
        )
    }
}

final class CovJMxSelectCurrencyViewTests: XCTestCase {
    private let viewModels = [
        SelectCurrencyCellViewModel(imageViewModel: nil, title: "US Dollar", isSelected: true, id: "usd"),
        SelectCurrencyCellViewModel(imageViewModel: nil, title: "Euro", isSelected: false, id: "eur")
    ]

    func testPushedListSelectsRowsAndConfirmsWithDone() throws {
        let output = CovJMxCurrencyViewOutput()
        let manager = try XCTUnwrap(LocalizationManager(localization: "en"))
        let controller = SelectCurrencyViewController(isModal: false, output: output, localizationManager: manager)
        let navigation = UINavigationController(rootViewController: controller)
        let window = try CovJViewFixture.host(navigation)
        defer { window.isHidden = true }
        let layout = try XCTUnwrap(controller.view as? SelectCurrencyViewLayout)
        XCTAssertTrue(CovJWait.until { output.loads == 1 })
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        XCTAssertTrue(navigation.isNavigationBarHidden)
        XCTAssertEqual(layout.titleLabel.text, R.string.localizable.commonCurrency(preferredLanguages: manager.selectedLocale.rLanguages))

        let table = layout.tableView
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 0)
        layout.rightButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(output.selections.isEmpty)

        controller.didRecieve(viewModel: viewModels)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 2)
        XCTAssertEqual(table.rowHeight, UIConstants.cellHeight)
        let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) as? SelectCurrencyTableCell)
        XCTAssertTrue(cell.isSelected)
        XCTAssertTrue(CovJViewFixture.descendants(UILabel.self, in: cell).contains { $0.text == "US Dollar" })

        controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 0))
        XCTAssertTrue(output.selections.isEmpty)
        let euro = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 1, section: 0)) as? SelectCurrencyTableCell)
        XCTAssertTrue(euro.isSelected)

        layout.rightButton.sendActions(for: .touchUpInside)
        layout.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.selections, ["eur"])
        XCTAssertEqual(output.backs, 1)
    }

    func testModalListConfirmsAsSoonAsARowIsChosen() throws {
        let output = CovJMxCurrencyViewOutput()
        let controller = SelectCurrencyViewController(
            isModal: true,
            output: output,
            localizationManager: try XCTUnwrap(LocalizationManager(localization: "en"))
        )
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let table = try XCTUnwrap(controller.view as? SelectCurrencyViewLayout).tableView
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertTrue(output.selections.isEmpty)

        controller.didRecieve(viewModel: viewModels)
        controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 0))

        XCTAssertEqual(output.selections, ["eur"])
    }

    func testCellShowsCheckmarkOnlyWhenSelected() throws {
        let cell = SelectCurrencyTableCell(style: .default, reuseIdentifier: nil)
        let images = CovJViewFixture.descendants(UIImageView.self, in: cell.contentView)

        cell.bind(viewModel: viewModels[0])
        XCTAssertTrue(cell.isSelected)
        XCTAssertTrue(images.contains { $0.image != nil })
        XCTAssertEqual(cell.selectionStyle, .none)

        cell.bind(viewModel: viewModels[1])
        XCTAssertTrue(CovJViewFixture.descendants(UILabel.self, in: cell.contentView).contains { $0.text == "Euro" })
    }

    func testRouterDismissesModalAndPopsPushedScreens() throws {
        let root = UIViewController()
        let window = try CovJViewFixture.host(root)
        defer { window.isHidden = true }

        let modal = CovJMxCurrencyView()
        root.present(modal, animated: false)
        XCTAssertTrue(CovJWait.until { root.presentedViewController === modal && !modal.isBeingPresented })
        SelectCurrencyRouter(viewIsModal: true).proceed(from: modal)
        XCTAssertTrue(CovJWait.until(timeout: 3) { root.presentedViewController == nil })

        root.present(modal, animated: false)
        XCTAssertTrue(CovJWait.until { root.presentedViewController === modal && !modal.isBeingPresented })
        SelectCurrencyRouter(viewIsModal: true).back(from: modal)
        XCTAssertTrue(CovJWait.until(timeout: 3) { root.presentedViewController == nil })

        let pushed = CovJMxCurrencyView()
        let navigation = UINavigationController(rootViewController: UIViewController())
        navigation.pushViewController(pushed, animated: false)
        root.present(navigation, animated: false)
        XCTAssertTrue(CovJWait.until { root.presentedViewController === navigation && !navigation.isBeingPresented })
        SelectCurrencyRouter(viewIsModal: false).back(from: pushed)
        XCTAssertTrue(CovJWait.until(timeout: 3) { navigation.viewControllers.count == 1 })

        // Without a navigation stack there is nothing to close.
        SelectCurrencyRouter(viewIsModal: false).proceed(from: CovJMxCurrencyView())
        XCTAssertTrue(root.presentedViewController === navigation)
        root.dismiss(animated: false)
    }

    func testAssemblyBuildsModalAndPushedScreensWithoutLoadingThem() throws {
        let wallet = AccountGenerator.generateMetaAccount()

        let modal = try XCTUnwrap(SelectCurrencyAssembly.configureModule(with: wallet, isModal: true))
        let modalController = try XCTUnwrap(modal.view.controller as? SelectCurrencyViewController)
        XCTAssertEqual(modalController.modalPresentationStyle, .custom)
        XCTAssertTrue(modal.input is SelectCurrencyPresenter)

        let pushed = try XCTUnwrap(SelectCurrencyAssembly.configureModule(with: wallet, isModal: false))
        XCTAssertNotEqual(pushed.view.controller.modalPresentationStyle, .custom)
    }
}
