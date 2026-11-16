import XCTest
import UIKit
import RobinHood
import SSFModels
import SoraFoundation
import SoraKeystore
@testable import fearless

final class CovJContactsView: UIViewController, ContactsViewInput {
    var sections: [[ContactsTableSectionModel]] = []
    var locales: [Locale] = []
    var sources: [ContactSource] = []
    var stops = 0
    func didReceive(sections: [ContactsTableSectionModel]) { self.sections.append(sections) }
    func didReceive(locale: Locale) { locales.append(locale) }
    func didReceive(source: ContactSource) { sources.append(source) }
    func didStartLoading() {}
    func didStopLoading() { stops += 1 }
}

final class CovJContactsInteractor: ContactsInteractorInput {
    weak var output: ContactsInteractorOutput?
    var saved: [Contact] = []
    func setup(with output: ContactsInteractorOutput) { self.output = output }
    func save(contact: Contact) { saved.append(contact) }
}

final class CovJContactsRouter: CovJSheetSpy, ContactsRouterInput {
    var dismissals = 0
    var creations: [(String?, String)] = []
    var scores: [String?] = []
    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }
    func createContact(address: String?, chain: ChainModel, output _: CreateContactModuleOutput, view _: ControllerBackedProtocol?) {
        creations.append((address, chain.chainId))
    }

    func presentAccountScore(address: String?, from _: ControllerBackedProtocol?) { scores.append(address) }
}

final class CovJContactsModuleOutput: ContactsModuleOutput {
    var selected: [String] = []
    func didSelect(address: String) { selected.append(address) }
}

final class CovJContactsViewOutput: ContactsViewOutput {
    var loads = 0
    var backs = 0
    var creates = 0
    var selected: [String] = []
    func didLoad(view _: ContactsViewInput) { loads += 1 }
    func didTapBackButton() { backs += 1 }
    func didTapCreateButton() { creates += 1 }
    func didSelect(address: String) { selected.append(address) }
}

final class CovJStatisticsFetcher: AccountStatisticsFetching {
    func subscribeForStatistics(address _: String) async throws -> AsyncThrowingStream<AccountStatisticsResponse, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func fetchStatistics(address _: String) async throws -> AccountStatisticsResponse? { nil }
}

final class CovJHistoryFactory: HistoryOperationFactoryProtocol {
    var page: AssetTransactionPageData?
    var failure: Error?
    var requests: [(String, [WalletTransactionHistoryFilter], Int)] = []

    func fetchTransactionHistoryOperation(
        asset _: AssetModel,
        chain _: ChainModel,
        address: String,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        requests.append((address, filters, pagination.count))
        let page = page
        let failure = failure
        let operation = ClosureOperation<AssetTransactionPageData?> {
            if let failure { throw failure }
            return page
        }
        return CompoundOperationWrapper(targetOperation: operation)
    }

    static func transaction(peer: String?) -> AssetTransactionData {
        AssetTransactionData(
            transactionId: UUID().uuidString, status: .commited, assetId: "asset", peerId: "peer", peerFirstName: nil,
            peerLastName: nil, peerName: peer, details: "", amount: AmountDecimal(value: 1), fees: [], timestamp: 0,
            type: "TRANSFER", reason: nil, context: nil
        )
    }
}

final class CovJContactsTests: XCTestCase {
    private let locale = CovJFixture.locale

    private func factory(chain: ChainModel) -> AddressBookViewModelFactory {
        AddressBookViewModelFactory(accountScoreFetcher: CovJStatisticsFetcher(), chain: chain, settings: InMemorySettingsManager())
    }

    func testFactoryGroupsSavedContactsByLetterAfterRecentSection() {
        let chain = CovJFixture.chain(id: "contacts")
        let delegate = CovJContactsCellDelegate()
        let alice = Contact(name: "Alice", address: "addr-alice", chainId: "contacts")
        let anna = Contact(name: "anna", address: "addr-anna", chainId: "contacts")
        let bob = Contact(name: "Bob", address: "addr-bob", chainId: "contacts")
        let sections = factory(chain: chain).buildCellViewModels(
            savedContacts: [bob, alice, anna],
            recentContacts: [.saved(alice), .unsaved("addr-stranger")],
            cellsDelegate: delegate,
            locale: locale
        )
        XCTAssertEqual(sections.first?.name, R.string.localizable.contactsRecent(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(sections.first?.cellViewModels.map(\.contactType.address), ["addr-alice", "addr-stranger"])
        let saved = sections.dropFirst()
        XCTAssertEqual(Set(saved.map(\.name)), ["A", "B", "a"])
        let aSections = saved.filter { $0.name.lowercased() == "a" }
        XCTAssertTrue(aSections.allSatisfy { Set($0.cellViewModels.map(\.contactType.address)) == ["addr-alice", "addr-anna"] })
        XCTAssertEqual(saved.first { $0.name == "B" }?.cellViewModels.map(\.contactType.address), ["addr-bob"])

        let cell = try? XCTUnwrap(sections.first?.cellViewModels.last)
        cell?.didTapAddButton()
        cell?.didTapAccountScore()
        XCTAssertEqual(delegate.added, ["addr-stranger"])
        XCTAssertEqual(delegate.scored, ["addr-stranger"])
        XCTAssertNotNil(cell?.accountScoreViewModel)
    }

    func testFactoryReturnsNothingWithoutContactsAndDropsEmptyRecentSection() {
        let chain = CovJFixture.chain(id: "contacts")
        let delegate = CovJContactsCellDelegate()
        XCTAssertTrue(factory(chain: chain).buildCellViewModels(savedContacts: [], recentContacts: [], cellsDelegate: delegate, locale: locale).isEmpty)
        let sections = factory(chain: chain).buildCellViewModels(
            savedContacts: [Contact(name: "Zed", address: "z", chainId: "contacts")],
            recentContacts: [],
            cellsDelegate: delegate,
            locale: locale
        )
        XCTAssertEqual(sections.map(\.name), ["Z"])
        XCTAssertEqual(ContactType.unsaved("x").address, "x")
        XCTAssertEqual(ContactType.saved(Contact(name: "Y", address: "y", chainId: "c")).address, "y")
    }

    func testPresenterLoadsSourceRoutesActionsAndSavesCreatedContact() {
        let chainAsset = CovJFixture.chainAsset(chainName: "Polkadot", symbol: "DOT")
        let interactor = CovJContactsInteractor()
        let router = CovJContactsRouter()
        let moduleOutput = CovJContactsModuleOutput()
        let presenter = ContactsPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            viewModelFactory: factory(chain: chainAsset.chain),
            moduleOutput: moduleOutput,
            source: .token(chainAsset: chainAsset),
            wallet: AccountGenerator.generateMetaAccount()
        )
        let view = CovJContactsView()
        presenter.didLoad(view: view)
        XCTAssertNotNil(interactor.output)
        XCTAssertEqual(view.locales.count, 1)
        XCTAssertEqual(view.sources.first?.chain.chainId, chainAsset.chain.chainId)

        presenter.didReceive(savedContacts: [Contact(name: "Carol", address: "c", chainId: chainAsset.chain.chainId)], recentContacts: [])
        XCTAssertEqual(view.sections.last?.map(\.name), ["C"])
        XCTAssertEqual(view.stops, 1)

        presenter.didReceiveError(CovJError())
        XCTAssertEqual(router.errors.count, 1)

        presenter.didTapCreateButton()
        presenter.addContact(address: "new-address")
        XCTAssertEqual(router.creations.map(\.0), [nil, "new-address"])
        XCTAssertTrue(router.creations.allSatisfy { $0.1 == chainAsset.chain.chainId })

        presenter.didTapAccountScore(address: "scored")
        XCTAssertEqual(router.scores, ["scored"])

        let contact = Contact(name: "Dave", address: "d", chainId: chainAsset.chain.chainId)
        presenter.didCreate(contact: contact)
        XCTAssertEqual(interactor.saved, [contact])

        presenter.didSelect(address: "picked")
        XCTAssertEqual(moduleOutput.selected, ["picked"])
        presenter.didTapBackButton()
        XCTAssertEqual(router.dismissals, 2)
        presenter.applyLocalization()
        XCTAssertEqual(view.locales.count, 2)
    }

    func testInteractorForNftSourceReturnsOnlyChainContactsAndRefetchesAfterSave() {
        let chain = CovJFixture.chain(id: "nft-chain")
        let repository = CovJMemoryRepository<Contact>([
            Contact(name: "Mine", address: "mine", chainId: "nft-chain"),
            Contact(name: "Other", address: "other", chainId: "elsewhere")
        ])
        let output = CovJContactsInteractorOutput()
        let interactor = ContactsInteractor(
            repository: AnyDataProviderRepository(repository),
            operationQueue: OperationQueue(),
            historyOperationFactory: CovJHistoryFactory(),
            wallet: AccountGenerator.generateMetaAccount(),
            source: .nft(chain: chain)
        )
        interactor.setup(with: output)
        XCTAssertTrue(CovJWait.until(timeout: 5) { output.received.count == 1 })
        XCTAssertEqual(output.received.first?.0.map(\.address), ["mine"])
        XCTAssertEqual(output.received.first?.1.count, 0)
        if case .waitingCached = interactor.dataLoadingState {} else { XCTFail("state stays waitingCached") }

        interactor.save(contact: Contact(name: "New", address: "new", chainId: "nft-chain"))
        XCTAssertTrue(CovJWait.until(timeout: 5) { output.received.count == 2 })
        XCTAssertEqual(Set(output.received.last?.0.map(\.address) ?? []), ["mine", "new"])
    }

    func testInteractorForTokenSourceMergesRecentPeersWithSavedContacts() throws {
        let chainAsset = CovJFixture.chainAsset(chainName: "Kusama", symbol: "KSM")
        let chainId = chainAsset.chain.chainId
        let repository = CovJMemoryRepository<Contact>([Contact(name: "Known", address: "known", chainId: chainId)])
        let history = CovJHistoryFactory()
        history.page = AssetTransactionPageData(transactions: [
            CovJHistoryFactory.transaction(peer: "known"),
            CovJHistoryFactory.transaction(peer: "stranger"),
            CovJHistoryFactory.transaction(peer: "stranger"),
            CovJHistoryFactory.transaction(peer: nil)
        ])
        let output = CovJContactsInteractorOutput()
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = ContactsInteractor(
            repository: AnyDataProviderRepository(repository),
            operationQueue: OperationQueue(),
            historyOperationFactory: history,
            wallet: wallet,
            source: .token(chainAsset: chainAsset)
        )
        interactor.setup(with: output)
        XCTAssertTrue(CovJWait.until(timeout: 5) { output.received.count == 1 })
        let request = try XCTUnwrap(history.requests.first)
        XCTAssertEqual(request.2, ContactsInteractor.Constants.recentTransfersCount)
        XCTAssertEqual(request.1.map(\.type), [.transfer, .other, .reward])
        XCTAssertEqual(request.1.map(\.selected), [true, false, false])
        let recent = try XCTUnwrap(output.received.first?.1)
        XCTAssertEqual(recent.count, 2)
        XCTAssertEqual(Set(recent.map(\.address)), ["known", "stranger"])
        for contact in recent {
            switch contact {
            case let .saved(saved): XCTAssertEqual(saved.name, "Known")
            case let .unsaved(address): XCTAssertEqual(address, "stranger")
            }
        }
    }

    func testViewControllerRendersSectionsEmptyStateAndForwardsTaps() throws {
        let output = CovJContactsViewOutput()
        let controller = ContactsViewController(output: output, localizationManager: LocalizationManager.shared)
        let navigation = UINavigationController(rootViewController: controller)
        let window = try CovJViewFixture.host(navigation)
        defer { window.isHidden = true }
        controller.loadViewIfNeeded()
        XCTAssertEqual(output.loads, 1)
        let layout = try XCTUnwrap(controller.view as? ContactsViewLayout)

        controller.didReceive(source: .nft(chain: CovJFixture.chain()))
        XCTAssertEqual(layout.navigationBar.titleLabel.text, R.string.localizable.walletSearchContacts(preferredLanguages: locale.rLanguages))
        controller.didReceive(source: .token(chainAsset: CovJFixture.chainAsset()))
        XCTAssertEqual(layout.navigationBar.titleLabel.text, R.string.localizable.walletHistoryTitle_v190(preferredLanguages: locale.rLanguages))

        controller.didReceive(sections: [])
        XCTAssertFalse(layout.emptyView.isHidden)

        let chain = CovJFixture.chain(id: "vc")
        let sections = factory(chain: chain).buildCellViewModels(
            savedContacts: [Contact(name: "Erin", address: "erin-address", chainId: "vc")],
            recentContacts: [.unsaved("recent-address")],
            cellsDelegate: CovJContactsCellDelegate(),
            locale: locale
        )
        controller.didReceive(sections: sections)
        XCTAssertTrue(layout.emptyView.isHidden)
        XCTAssertFalse(layout.tableView.isHidden)
        let table = layout.tableView
        XCTAssertEqual(controller.numberOfSections(in: table), 2)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 1)
        XCTAssertEqual(controller.tableView(table, titleForHeaderInSection: 1), "E")
        XCTAssertEqual(controller.tableView(table, heightForRowAt: IndexPath(row: 0, section: 0)), 52)
        for section in 0 ..< 2 {
            let indexPath = IndexPath(row: 0, section: section)
            let cell = controller.tableView(table, cellForRowAt: indexPath)
            controller.tableView(table, willDisplay: cell, forRowAt: indexPath)
            let contactCell = try XCTUnwrap(cell as? ContactTableCell)
            let texts = CovJViewFixture.descendants(UILabel.self, in: contactCell).compactMap(\.text)
            XCTAssertTrue(texts.contains(sections[section].cellViewModels[0].contactType.address))
            XCTAssertEqual(contactCell.addButton.isHidden, section == 1, "saved contacts hide the add button")
        }
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 1))
        XCTAssertEqual(output.selected, ["erin-address"])
        layout.navigationBar.backButton.sendActions(for: .touchUpInside)
        layout.createButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.backs, 1)
        XCTAssertEqual(output.creates, 1)
        controller.applyLocalization()
        XCTAssertEqual(layout.locale, controller.selectedLocale)
    }

    func testRouterPushesCreateContactScreen() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        ContactsRouter().createContact(address: "prefilled", chain: CovJFixture.chain(), output: CovJCreateContactOutput(), view: host)
        XCTAssertTrue(host.navigation.viewControllers.last is CreateContactViewController)
    }
}

final class CovJContactsCellDelegate: ContactTableCellModelDelegate {
    var added: [String] = []
    var scored: [String] = []
    func addContact(address: String) { added.append(address) }
    func didTapAccountScore(address: String) { scored.append(address) }
}

final class CovJContactsInteractorOutput: ContactsInteractorOutput {
    var received: [([Contact], [ContactType])] = []
    var errors: [Error] = []
    func didReceive(savedContacts: [Contact], recentContacts: [ContactType]) { received.append((savedContacts, recentContacts)) }
    func didReceiveError(_ error: Error) { errors.append(error) }
}

final class CovJCreateContactOutput: CreateContactModuleOutput {
    var created: [Contact] = []
    func didCreate(contact: Contact) { created.append(contact) }
}

final class CovJCreateContactTests: XCTestCase {
    private let alice = "5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY"

    private func type(_ text: String, into field: UITextField, controller: CreateContactViewController) {
        let current = (field.text ?? "") as NSString
        _ = controller.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: current.length), replacementString: text)
        field.text = text
    }

    func testAssembledModuleValidatesInputAndCreatesContact() throws {
        let output = CovJCreateContactOutput()
        let chain = CovJFixture.chain(id: "create", name: "Westend", addressPrefix: 42)
        let module = try XCTUnwrap(CreateContactAssembly.configureModule(moduleOutput: output, chain: chain, address: nil))
        let controller = try XCTUnwrap(module.view.controller as? CreateContactViewController)
        let host = try CovJHostedView()
        defer { host.close() }
        host.navigation.pushViewController(controller, animated: false)
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
        let layout = try XCTUnwrap(controller.view as? CreateContactViewLayout)
        XCTAssertEqual(layout.networkView.subtitle, "Westend")
        XCTAssertFalse(layout.createButton.isEnabled)

        type("Alice", into: layout.contactNameField.textField, controller: controller)
        XCTAssertFalse(layout.createButton.isEnabled, "a name alone is not enough")
        type("not-an-address", into: layout.contactAddressField.textField, controller: controller)
        XCTAssertFalse(layout.createButton.isEnabled)
        type(alice, into: layout.contactAddressField.textField, controller: controller)
        XCTAssertTrue(layout.createButton.isEnabled)

        XCTAssertTrue(controller.textFieldShouldClear(layout.contactNameField.textField))
        XCTAssertFalse(layout.createButton.isEnabled)
        layout.contactNameField.textField.text = "Alice"
        XCTAssertFalse(controller.textFieldShouldReturn(layout.contactNameField.textField))
        XCTAssertTrue(layout.createButton.isEnabled)
        XCTAssertFalse(controller.textFieldShouldReturn(layout.contactAddressField.textField))
        XCTAssertTrue(controller.textFieldShouldClear(layout.contactAddressField.textField))
        XCTAssertFalse(layout.createButton.isEnabled)
        layout.contactAddressField.textField.text = alice
        _ = controller.textFieldShouldReturn(layout.contactAddressField.textField)

        layout.createButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.created, [Contact(name: "Alice", address: alice, chainId: "create")])
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(0), UIConstants.bigOffset)
        XCTAssertTrue(controller.shouldApplyKeyboardFrame)
        XCTAssertNotNil(controller.target)
        controller.updateWhileKeyboardFrameChanging(.zero)
        controller.applyLocalization()
        XCTAssertEqual(layout.locale, controller.selectedLocale)
    }

    func testPrefilledAddressIsShownAndBackPops() throws {
        let output = CovJCreateContactOutput()
        let chain = CovJFixture.chain(id: "prefill", name: "Kusama", icon: nil, addressPrefix: 2)
        let viewModel = CreateContactViewModelFactory().buildViewModel(address: "prefilled", chain: chain)
        XCTAssertEqual(viewModel.address, "prefilled")
        XCTAssertEqual(viewModel.chainName, "Kusama")
        XCTAssertNil(viewModel.iconViewModel)
        let module = try XCTUnwrap(CreateContactAssembly.configureModule(moduleOutput: output, chain: chain, address: "prefilled"))
        let controller = try XCTUnwrap(module.view.controller as? CreateContactViewController)
        let host = try CovJHostedView()
        defer { host.close() }
        host.navigation.pushViewController(controller, animated: false)
        controller.loadViewIfNeeded()
        let layout = try XCTUnwrap(controller.view as? CreateContactViewLayout)
        XCTAssertEqual(layout.contactAddressField.textField.text, "prefilled")
        layout.createButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(output.created.isEmpty, "no name, no contact")
        layout.navigationBar.backButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(CovJWait.until { host.navigation.viewControllers.count == 1 })
        XCTAssertFalse(CreateContactInteractor().validate(address: "bad", for: chain))
    }
}
