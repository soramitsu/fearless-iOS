import XCTest
import UIKit
import FearlessFoundation
import FearlessSecureStorage
import SSFModels
@testable import fearless

final class ContactsTests: XCTestCase {
    func testDidLoad_whenViewProvided_thenSetsUpInteractorAndProvidesLocaleAndSource() {
        let interactor = ContactsInteractorInputSpy()
        let source = makeSource()
        let presenter = createPresenter(interactor: interactor, source: source)
        let view = ContactsViewSpy()

        presenter.didLoad(view: view)

        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(view.receivedLocale, LocalizationManager.shared.selectedLocale)
        XCTAssertEqual(view.receivedSource?.chain.chainId, source.chain.chainId)
    }

    func testDidTapCreateButton_whenViewLoaded_thenRoutesToCreateContact() {
        let router = ContactsRouterSpy()
        let source = makeSource()
        let presenter = createPresenter(router: router, source: source)
        let view = ContactsViewSpy()

        presenter.didLoad(view: view)
        presenter.didTapCreateButton()

        XCTAssertNil(router.createContactAddress)
        XCTAssertEqual(router.createContactChain?.chainId, source.chain.chainId)
        XCTAssertTrue(router.createContactOutput === presenter)
        XCTAssertTrue(router.createContactView === view)
    }

    func testDidSelect_whenAddressSelected_thenOutputsAddressAndDismisses() {
        let router = ContactsRouterSpy()
        let moduleOutput = ContactsModuleOutputSpy()
        let presenter = createPresenter(router: router, moduleOutput: moduleOutput)
        let view = ContactsViewSpy()

        presenter.didLoad(view: view)
        presenter.didSelect(address: "selected-address")

        XCTAssertEqual(moduleOutput.selectedAddress, "selected-address")
        XCTAssertTrue(router.dismissedView === view)
    }

    func testDidReceiveContacts_whenInteractorProvidesContacts_thenBuildsSectionsAndStopsLoading() {
        let factory = AddressBookViewModelFactorySpy(
            sections: [
                ContactsTableSectionModel(name: "Recent", cellViewModels: [])
            ]
        )
        let presenter = createPresenter(viewModelFactory: factory)
        let view = ContactsViewSpy()
        let savedContact = Contact(name: "Alice", address: "alice-address", chainId: "chain")

        presenter.didLoad(view: view)
        presenter.didReceive(savedContacts: [savedContact], recentContacts: [.unsaved("recent-address")])

        XCTAssertEqual(factory.savedContacts, [savedContact])
        XCTAssertEqual(factory.recentContactAddresses, ["recent-address"])
        XCTAssertTrue(factory.cellsDelegate === presenter)
        XCTAssertEqual(view.sections?.map(\.name), ["Recent"])
        XCTAssertEqual(view.didStopLoadingCallCount, 1)
    }

    func testAddressBookViewModelFactory_whenAccountScoreSetup_thenUsesInjectedEventCenterAndLogger() {
        let eventCenter = ContactsAccountScoreEventCenterSpy()
        let logger = ContactsAccountScoreLoggerSpy()
        let loggerExpectation = expectation(description: "contacts account score logger")
        loggerExpectation.expectedFulfillmentCount = 2
        logger.onDebug = { message in
            if message.contains("Account statistics fetching error") {
                loggerExpectation.fulfill()
            }
        }
        let factory = AddressBookViewModelFactory(
            accountScoreFetcher: ContactsAccountStatisticsFetcherStub(),
            chain: ChainModelGenerator.generate(count: 1).first!,
            settings: InMemorySettingsManager(),
            eventCenter: eventCenter,
            logger: logger
        )
        let sections = factory.buildCellViewModels(
            savedContacts: [
                Contact(name: "Alice", address: "alice-address", chainId: "chain")
            ],
            recentContacts: [.unsaved("recent-address")],
            cellsDelegate: ContactsTableCellDelegateSpy(),
            locale: Locale(identifier: "en_US")
        )
        let accountScoreViewModels = sections
            .flatMap(\.cellViewModels)
            .compactMap(\.accountScoreViewModel)

        XCTAssertEqual(accountScoreViewModels.count, 2)
        accountScoreViewModels.forEach { accountScoreViewModel in
            accountScoreViewModel.setup(with: nil)
        }
        accountScoreViewModels.forEach { accountScoreViewModel in
            XCTAssertTrue(eventCenter.observers.contains { $0 === accountScoreViewModel })
        }
        wait(for: [loggerExpectation], timeout: Constants.defaultExpectationDuration)
    }

    func testDidReceiveError_whenInteractorFails_thenPresentsError() {
        let router = ContactsRouterSpy()
        let presenter = createPresenter(router: router)
        let view = ContactsViewSpy()

        presenter.didLoad(view: view)
        presenter.didReceiveError(ContactsTestError.failure)

        XCTAssertTrue(router.presentedError is ContactsTestError)
        XCTAssertTrue(router.errorView === view)
    }

    func testContactCellDelegateActions_whenTriggered_thenRouteToCreateContactAndAccountScore() {
        let router = ContactsRouterSpy()
        let source = makeSource()
        let presenter = createPresenter(router: router, source: source)
        let view = ContactsViewSpy()

        presenter.didLoad(view: view)
        presenter.addContact(address: "recent-address")
        presenter.didTapAccountScore(address: "score-address")

        XCTAssertEqual(router.createContactAddress, "recent-address")
        XCTAssertEqual(router.createContactChain?.chainId, source.chain.chainId)
        XCTAssertTrue(router.createContactView === view)
        XCTAssertEqual(router.accountScoreAddress, "score-address")
        XCTAssertTrue(router.accountScoreView === view)
    }

    func testDidCreateContact_whenCreateContactOutputsContact_thenSavesContact() {
        let interactor = ContactsInteractorInputSpy()
        let presenter = createPresenter(interactor: interactor)
        let contact = Contact(name: "Alice", address: "alice-address", chainId: "chain")

        presenter.didCreate(contact: contact)

        XCTAssertEqual(interactor.savedContact, contact)
    }

    private func createPresenter(
        interactor: ContactsInteractorInput = ContactsInteractorInputSpy(),
        router: ContactsRouterInput = ContactsRouterSpy(),
        viewModelFactory: AddressBookViewModelFactoryProtocol = AddressBookViewModelFactorySpy(),
        moduleOutput: ContactsModuleOutput = ContactsModuleOutputSpy(),
        source: ContactSource = .nft(chain: ChainModelGenerator.generate(count: 1).first!),
        wallet: MetaAccountModel = AccountGenerator.generateMetaAccount()
    ) -> ContactsPresenter {
        ContactsPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            viewModelFactory: viewModelFactory,
            moduleOutput: moduleOutput,
            source: source,
            wallet: wallet
        )
    }

    private func makeSource() -> ContactSource {
        .nft(chain: ChainModelGenerator.generate(count: 1).first!)
    }
}

private final class ContactsViewSpy: ContactsViewInput {
    let controller = UIViewController()
    let isSetup = false
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = true
    private(set) var sections: [ContactsTableSectionModel]?
    private(set) var receivedLocale: Locale?
    private(set) var receivedSource: ContactSource?
    private(set) var didStartLoadingCallCount = 0
    private(set) var didStopLoadingCallCount = 0

    func didReceive(sections: [ContactsTableSectionModel]) {
        self.sections = sections
    }

    func didReceive(locale: Locale) {
        receivedLocale = locale
    }

    func didReceive(source: ContactSource) {
        receivedSource = source
    }

    func didStartLoading() {
        didStartLoadingCallCount += 1
    }

    func didStopLoading() {
        didStopLoadingCallCount += 1
    }
}

private final class ContactsInteractorInputSpy: ContactsInteractorInput {
    private(set) weak var output: ContactsInteractorOutput?
    private(set) var savedContact: Contact?

    func setup(with output: ContactsInteractorOutput) {
        self.output = output
    }

    func save(contact: Contact) {
        savedContact = contact
    }
}

private final class ContactsRouterSpy: ContactsRouterInput {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var errorView: ControllerBackedProtocol?
    private(set) weak var createContactView: ControllerBackedProtocol?
    private(set) weak var accountScoreView: ControllerBackedProtocol?
    private(set) weak var createContactOutput: CreateContactModuleOutput?
    private(set) var createContactAddress: String?
    private(set) var createContactChain: ChainModel?
    private(set) var accountScoreAddress: String?
    private(set) var presentedError: Error?

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func createContact(
        address: String?,
        chain: ChainModel,
        output: CreateContactModuleOutput,
        view: ControllerBackedProtocol?
    ) {
        createContactAddress = address
        createContactChain = chain
        createContactOutput = output
        createContactView = view
    }

    func presentAccountScore(
        address: String?,
        from view: ControllerBackedProtocol?
    ) {
        accountScoreAddress = address
        accountScoreView = view
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

private final class AddressBookViewModelFactorySpy: AddressBookViewModelFactoryProtocol {
    private(set) var savedContacts: [Contact] = []
    private(set) var recentContactAddresses: [String] = []
    private(set) weak var cellsDelegate: ContactTableCellModelDelegate?
    private let sections: [ContactsTableSectionModel]

    init(sections: [ContactsTableSectionModel] = []) {
        self.sections = sections
    }

    func buildCellViewModels(
        savedContacts: [Contact],
        recentContacts: [ContactType],
        cellsDelegate: ContactTableCellModelDelegate,
        locale _: Locale
    ) -> [ContactsTableSectionModel] {
        self.savedContacts = savedContacts
        recentContactAddresses = recentContacts.map(\.address)
        self.cellsDelegate = cellsDelegate
        return sections
    }
}

private final class ContactsModuleOutputSpy: ContactsModuleOutput {
    private(set) var selectedAddress: String?

    func didSelect(address: String) {
        selectedAddress = address
    }
}

private final class ContactsTableCellDelegateSpy: ContactTableCellModelDelegate {
    func addContact(address _: String) {}
    func didTapAccountScore(address _: String) {}
}

private final class ContactsAccountScoreEventCenterSpy: EventCenterProtocol {
    private(set) var observers: [EventVisitorProtocol] = []

    func notify(with _: EventProtocol) {}

    func add(observer: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {
        observers.append(observer)
    }

    func remove(observer _: EventVisitorProtocol) {}
}

private final class ContactsAccountScoreLoggerSpy: LoggerProtocol {
    var onDebug: ((String) -> Void)?

    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message: String, file _: String, function _: String, line _: Int) {
        onDebug?(message)
    }

    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}
    func customError(error _: Error, file _: String, function _: String, line _: Int) {}
}

private enum ContactsAccountScoreDependencyTestError: Error {
    case subscription
}

private struct ContactsAccountStatisticsFetcherStub: AccountStatisticsFetching {
    func subscribeForStatistics(
        address _: String
    ) async throws -> AsyncThrowingStream<AccountStatisticsResponse, Error> {
        throw ContactsAccountScoreDependencyTestError.subscription
    }

    func fetchStatistics(address _: String) async throws -> AccountStatisticsResponse? {
        nil
    }
}

private enum ContactsTestError: Error {
    case failure
}
