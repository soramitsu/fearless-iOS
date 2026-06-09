import XCTest
import UIKit
import FearlessFoundation
import FearlessSecureStorage
import RobinHood
import SSFModels
@testable import fearless

final class SelectCurrencyTests: XCTestCase {
    func testDidLoad_whenViewIsProvided_thenSetsUpInteractor() {
        let interactor = SelectCurrencyInteractorInputSpy()
        let presenter = createPresenter(interactor: interactor)
        let view = SelectCurrencyViewSpy()

        presenter.didLoad(view: view)

        XCTAssertTrue(interactor.output === presenter)
    }

    func testDidRecieve_whenSelectedAndSupportedCurrenciesArrive_thenBuildsAndPassesViewModel() {
        let viewModel = [
            SelectCurrencyCellViewModel(
                imageViewModel: nil,
                title: "Euro",
                isSelected: true,
                id: "eur"
            )
        ]
        let factory = SelectCurrencyViewModelFactorySpy(viewModel: viewModel)
        let presenter = createPresenter(viewModelFactory: factory)
        let view = SelectCurrencyViewSpy()
        let supportedCurrencies = [Currency.defaultCurrency(), Currency.euro()]

        presenter.didLoad(view: view)
        presenter.didRecieve(selectedCurrency: Currency.euro())

        XCTAssertNil(view.receivedViewModel)

        presenter.didRecieve(supportedСurrencies: .success(supportedCurrencies))

        XCTAssertEqual(factory.receivedSupportedCurrencies, supportedCurrencies)
        XCTAssertEqual(factory.receivedSelectedCurrency, Currency.euro())
        XCTAssertEqual(view.receivedViewModel?.map(\.id), ["eur"])
    }

    func testDidSelect_whenViewModelMatchesSupportedCurrency_thenSelectsCurrencyAndProceeds() {
        let interactor = SelectCurrencyInteractorInputSpy()
        let router = SelectCurrencyRouterSpy()
        let presenter = createPresenter(interactor: interactor, router: router)
        let view = SelectCurrencyViewSpy()

        presenter.didLoad(view: view)
        presenter.didRecieve(supportedСurrencies: .success([Currency.defaultCurrency(), Currency.euro()]))
        presenter.didSelect(
            viewModel: SelectCurrencyCellViewModel(
                imageViewModel: nil,
                title: "Euro",
                isSelected: false,
                id: "eur"
            )
        )

        XCTAssertEqual(interactor.selectedCurrency?.id, "eur")
        XCTAssertEqual(interactor.selectedCurrency?.isSelected, true)
        XCTAssertTrue(router.proceededView === view)
    }

    func testDidSelect_whenViewModelDoesNotMatchSupportedCurrency_thenDoesNotProceed() {
        let interactor = SelectCurrencyInteractorInputSpy()
        let router = SelectCurrencyRouterSpy()
        let presenter = createPresenter(interactor: interactor, router: router)

        presenter.didRecieve(supportedСurrencies: .success([Currency.defaultCurrency()]))
        presenter.didSelect(
            viewModel: SelectCurrencyCellViewModel(
                imageViewModel: nil,
                title: "Euro",
                isSelected: false,
                id: "eur"
            )
        )

        XCTAssertNil(interactor.selectedCurrency)
        XCTAssertNil(router.proceededView)
    }

    func testBack_whenCalled_thenRoutesBack() {
        let router = SelectCurrencyRouterSpy()
        let presenter = createPresenter(router: router)
        let view = SelectCurrencyViewSpy()

        presenter.didLoad(view: view)
        presenter.back()

        XCTAssertTrue(router.backView === view)
    }

    func testDidRecieve_whenSupportedCurrenciesFail_thenPresentsError() {
        let router = SelectCurrencyRouterSpy()
        let presenter = createPresenter(router: router)
        let view = SelectCurrencyViewSpy()

        presenter.didLoad(view: view)
        presenter.didRecieve(supportedСurrencies: .failure(SelectCurrencyTestError.failure))

        XCTAssertTrue(router.presentedError is SelectCurrencyTestError)
        XCTAssertTrue(router.errorView === view)
    }

    func testViewModelFactory_whenCurrencyIsSelected_thenMarksSelectedAndCreatesImageViewModel() {
        let viewModel = SelectCurrencyViewModelFactory().buildViewModel(
            supportedСurrencies: [Currency.defaultCurrency(), Currency.euro()],
            selectedCurrency: Currency.euro()
        )

        XCTAssertEqual(viewModel.map(\.id), ["usd", "eur"])
        XCTAssertEqual(viewModel.first(where: { $0.id == "eur" })?.isSelected, true)
        XCTAssertEqual(viewModel.first(where: { $0.id == "usd" })?.isSelected, false)
        XCTAssertNotNil(viewModel.first(where: { $0.id == "eur" })?.imageViewModel)
    }

    func testInteractorSetup_whenFiatsURLMissing_thenSkipsJsonSubscription() {
        let jsonFactory = SelectCurrencyJsonDataProviderFactorySpy(supportedCurrencies: [Currency.defaultCurrency()])
        let output = SelectCurrencyInteractorOutputSpy()
        let interactor = createInteractor(
            jsonDataProviderFactory: jsonFactory,
            configSource: SelectCurrencyConfigSourceStub(fiatsURL: nil)
        )

        interactor.setup(with: output)

        XCTAssertEqual(output.selectedCurrency?.id, Currency.defaultCurrency().id)
        XCTAssertTrue(jsonFactory.requestedURLs.isEmpty)
        XCTAssertNil(output.supportedCurrenciesResult)
    }

    func testInteractorSetup_whenFiatsURLExists_thenUsesInjectedURL() {
        let expectedURL = URL(string: "https://example.com/fiats.json")!
        let supportedCurrencies = [Currency.defaultCurrency(), Currency.euro()]
        let jsonFactory = SelectCurrencyJsonDataProviderFactorySpy(supportedCurrencies: supportedCurrencies)
        let output = SelectCurrencyInteractorOutputSpy()
        let expectation = expectation(description: "supported currencies delivered")
        output.onSupportedCurrencies = { result in
            if case .success = result {
                expectation.fulfill()
            }
        }
        let interactor = createInteractor(
            jsonDataProviderFactory: jsonFactory,
            configSource: SelectCurrencyConfigSourceStub(fiatsURL: expectedURL)
        )

        interactor.setup(with: output)

        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
        XCTAssertEqual(jsonFactory.requestedURLs, [expectedURL])
        XCTAssertEqual(output.supportedCurrencies?.map(\.id), supportedCurrencies.map(\.id))
    }

    private func createPresenter(
        interactor: SelectCurrencyInteractorInput = SelectCurrencyInteractorInputSpy(),
        router: SelectCurrencyRouterInput = SelectCurrencyRouterSpy(),
        viewModelFactory: SelectCurrencyViewModelFactoryProtocol = SelectCurrencyViewModelFactorySpy()
    ) -> SelectCurrencyPresenter {
        SelectCurrencyPresenter(
            interactor: interactor,
            router: router,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )
    }

    private func createInteractor(
        jsonDataProviderFactory: JsonDataProviderFactoryProtocol,
        configSource: SelectCurrencyConfigSource
    ) -> SelectCurrencyInteractor {
        let storageFacade = UserDataStorageTestFacade()
        let repository = AccountRepositoryFactory(storageFacade: storageFacade)
            .createMetaAccountRepository(for: nil, sortDescriptors: [])

        return SelectCurrencyInteractor(
            selectedMetaAccount: AccountGenerator.generateMetaAccount(),
            repository: AnyDataProviderRepository(repository),
            jsonDataProviderFactory: jsonDataProviderFactory,
            eventCenter: EventCenter(syncQueue: DispatchQueue(label: "test.select.currency.events")),
            operationQueue: OperationQueue(),
            configSource: configSource
        )
    }
}

private final class SelectCurrencyViewSpy: SelectCurrencyViewInput {
    let controller = UIViewController()
    let isSetup = false
    private(set) var receivedViewModel: [SelectCurrencyCellViewModel]?

    func didRecieve(viewModel: [SelectCurrencyCellViewModel]) {
        receivedViewModel = viewModel
    }
}

private final class SelectCurrencyInteractorInputSpy: SelectCurrencyInteractorInput {
    private(set) weak var output: SelectCurrencyInteractorOutput?
    private(set) var selectedCurrency: Currency?

    func setup(with output: SelectCurrencyInteractorOutput) {
        self.output = output
    }

    func didSelect(_ currency: Currency) {
        selectedCurrency = currency
    }
}

private final class SelectCurrencyInteractorOutputSpy: SelectCurrencyInteractorOutput {
    private(set) var selectedCurrency: Currency?
    private(set) var supportedCurrenciesResult: Result<[Currency], Error>?
    var onSupportedCurrencies: ((Result<[Currency], Error>) -> Void)?

    var supportedCurrencies: [Currency]? {
        try? supportedCurrenciesResult?.get()
    }

    func didRecieve(supportedСurrencies: Result<[Currency], Error>) {
        supportedCurrenciesResult = supportedСurrencies
        onSupportedCurrencies?(supportedСurrencies)
    }

    func didRecieve(selectedCurrency: Currency) {
        self.selectedCurrency = selectedCurrency
    }
}

private struct SelectCurrencyConfigSourceStub: SelectCurrencyConfigSource {
    let fiatsURL: URL?
}

private final class SelectCurrencyJsonDataProviderFactorySpy: JsonDataProviderFactoryProtocol {
    private let supportedCurrencies: [Currency]
    private(set) var requestedURLs: [URL] = []

    init(supportedCurrencies: [Currency]) {
        self.supportedCurrencies = supportedCurrencies
    }

    func getJson<T>(
        for url: URL
    ) throws -> AnySingleValueProvider<T> where T: Decodable, T: Encodable, T: Equatable {
        requestedURLs.append(url)
        let provider = SingleValueProviderStub(item: supportedCurrencies as? T)
        return AnySingleValueProvider(provider)
    }
}

private final class SelectCurrencyRouterSpy: SelectCurrencyRouterInput {
    private(set) weak var proceededView: SelectCurrencyViewInput?
    private(set) weak var backView: SelectCurrencyViewInput?
    private(set) var presentedError: Error?
    private(set) weak var errorView: ControllerBackedProtocol?

    func proceed(from view: SelectCurrencyViewInput?) {
        proceededView = view
    }

    func back(from view: SelectCurrencyViewInput?) {
        backView = view
    }

    func present(error: Error, from view: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedError = error
        errorView = view
        return true
    }

    func present(
        viewModel _: SheetAlertPresentableViewModel,
        from _: ControllerBackedProtocol?
    ) {}

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {}

    func presentInfo(
        message _: String?,
        title _: String,
        from _: ControllerBackedProtocol?
    ) {}
}

private final class SelectCurrencyViewModelFactorySpy: SelectCurrencyViewModelFactoryProtocol {
    private(set) var receivedSupportedCurrencies: [Currency]?
    private(set) var receivedSelectedCurrency: Currency?
    private let viewModel: [SelectCurrencyCellViewModel]

    init(viewModel: [SelectCurrencyCellViewModel] = []) {
        self.viewModel = viewModel
    }

    func buildViewModel(
        supportedСurrencies: [Currency],
        selectedCurrency: Currency
    ) -> [SelectCurrencyCellViewModel] {
        receivedSupportedCurrencies = supportedСurrencies
        receivedSelectedCurrency = selectedCurrency
        return viewModel
    }
}

private enum SelectCurrencyTestError: Error {
    case failure
}
