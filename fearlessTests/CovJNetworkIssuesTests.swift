import XCTest
import UIKit
import RobinHood
import SSFModels
import SoraFoundation
@testable import fearless

final class CovJIssuesView: UIViewController, NetworkIssuesNotificationViewInput {
    var received: [[NetworkIssuesNotificationCellViewModel]] = []
    func didReceive(viewModel: [NetworkIssuesNotificationCellViewModel]) { received.append(viewModel) }
}

final class CovJIssuesInteractor: NetworkIssuesNotificationInteractorInput {
    weak var output: NetworkIssuesNotificationInteractorOutput?
    var unused: [String] = []
    var muted: [String] = []
    func setup(with output: NetworkIssuesNotificationInteractorOutput) { self.output = output }
    func markUnused(chain: ChainModel) { unused.append(chain.chainId) }
    func mute(chain: ChainModel) { muted.append(chain.chainId) }
}

final class CovJIssuesRouter: CovJSheetSpy, NetworkIssuesNotificationRouterInput {
    var dismissed = 0
    var nodeSelections: [String] = []
    var accountOptions: [[MissingAccountOption]] = []
    var skip: ((ChainModel) -> Void)?

    func dismiss(view _: ControllerBackedProtocol?) { dismissed += 1 }
    func presentAccountOptions(
        from _: ControllerBackedProtocol?,
        locale _: Locale?,
        options: [MissingAccountOption],
        uniqueChainModel _: UniqueChainModel,
        skipBlock: @escaping (ChainModel) -> Void
    ) {
        accountOptions.append(options)
        skip = skipBlock
    }

    func presentNodeSelection(from _: ControllerBackedProtocol?, chain: ChainModel) { nodeSelections.append(chain.chainId) }
}

final class CovJIssuesOutput: NetworkIssuesNotificationViewOutput {
    var loads = 0
    var dismissals = 0
    var taps: [IndexPath?] = []
    func didLoad(view _: NetworkIssuesNotificationViewInput) { loads += 1 }
    func dissmis() { dismissals += 1 }
    func didTapCellAction(indexPath: IndexPath?) { taps.append(indexPath) }
}

final class CovJIssuesCenter: ChainsIssuesCenterProtocol {
    var listeners: [ChainsIssuesCenterListener] = []
    var forced = 0
    func addIssuesListener(_ listener: ChainsIssuesCenterListener, getExisting _: Bool) { listeners.append(listener) }
    func removeIssuesListener(_: ChainsIssuesCenterListener) { listeners.removeAll() }
    func forceNotify() { forced += 1 }
}

final class CovJIssuesInteractorOutput: NetworkIssuesNotificationInteractorOutput {
    var wallets: [MetaAccountModel] = []
    var issues: [[ChainIssue]] = []
    var settings: [[ChainSettings]] = []
    func didReceiveWallet(wallet: MetaAccountModel) { wallets.append(wallet) }
    func didReceiveChainsIssues(issues: [ChainIssue]) { self.issues.append(issues) }
    func didReceive(chainSettings: [ChainSettings]) { settings.append(chainSettings) }
}

final class CovJNetworkIssuesTests: XCTestCase {
    private let locale = CovJFixture.locale

    private func makePresenter(
        issues: [ChainIssue],
        wallet: MetaAccountModel = AccountGenerator.generateMetaAccount()
    ) -> (NetworkIssuesNotificationPresenter, CovJIssuesView, CovJIssuesInteractor, CovJIssuesRouter) {
        let interactor = CovJIssuesInteractor()
        let router = CovJIssuesRouter()
        let presenter = NetworkIssuesNotificationPresenter(
            wallet: wallet,
            issues: issues,
            viewModelFactory: NetworkIssuesNotificationViewModelFactory(),
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared
        )
        let view = CovJIssuesView()
        presenter.didLoad(view: view)
        return (presenter, view, interactor, router)
    }

    func testFactoryBuildsNodeNetworkAndMissingAccountRowsAndSkipsMutedChains() {
        let single = CovJFixture.chain(id: "single", name: "Single", nodeCount: 1)
        let multi = CovJFixture.chain(id: "multi", name: "Multi", nodeCount: 2, icon: nil)
        let muted = CovJFixture.chain(id: "muted", name: "Muted", nodeCount: 2)
        let missing = CovJFixture.chain(id: "missing", name: "Missing")
        var mutedSettings = ChainSettings.defaultSettings(for: "muted")
        mutedSettings.setIssueMuted(true)
        let rows = NetworkIssuesNotificationViewModelFactory().buildViewModel(
            for: [.network(chains: [single, multi, muted]), .missingAccount(chains: [missing])],
            locale: locale,
            chainSettings: [mutedSettings, ChainSettings.defaultSettings(for: "single")]
        )
        XCTAssertEqual(rows.map(\.chain.chainId), ["single", "multi", "missing"])
        let network = R.string.localizable.commonNetwork(preferredLanguages: locale.rLanguages)
        XCTAssertEqual(rows[0].chainNameTitle, "Single " + network)
        XCTAssertEqual(rows[0].issueDescription, R.string.localizable.networkIssueStub(preferredLanguages: locale.rLanguages))
        XCTAssertNotNil(rows[0].imageViewViewModel)
        guard case let .networkUnavailible(resolve) = rows[0].buttonType else { return XCTFail("single node can't switch") }
        XCTAssertEqual(resolve, R.string.localizable.commonResolve(preferredLanguages: locale.rLanguages))
        XCTAssertNil(rows[1].imageViewViewModel)
        XCTAssertEqual(rows[1].issueDescription, R.string.localizable.networkIssueNodeUnavailable(preferredLanguages: locale.rLanguages))
        guard case let .switchNode(switchTitle) = rows[1].buttonType else { return XCTFail("multi node offers switch") }
        XCTAssertEqual(switchTitle, R.string.localizable.switchNode(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(rows[2].chainNameTitle, "Missing")
        XCTAssertEqual(rows[2].issueDescription, R.string.localizable.manageAssetsAccountMissingText(preferredLanguages: locale.rLanguages))
        guard case let .missingAccount(add) = rows[2].buttonType else { return XCTFail("missing account row") }
        XCTAssertEqual(add, R.string.localizable.accountsAddAccount(preferredLanguages: locale.rLanguages))
    }

    func testPresenterWaitsForSettingsThenRoutesEachRowAction() throws {
        let single = CovJFixture.chain(id: "single", name: "Single", nodeCount: 1)
        let multi = CovJFixture.chain(id: "multi", name: "Multi", nodeCount: 3)
        let missing = CovJFixture.chain(id: "missing", name: "Missing")
        let (presenter, view, interactor, router) = makePresenter(
            issues: [.network(chains: [single, multi]), .missingAccount(chains: [missing])]
        )
        XCTAssertNotNil(interactor.output)
        XCTAssertTrue(view.received.isEmpty, "Nothing is shown before chain settings arrive")
        presenter.didReceive(chainSettings: [])
        XCTAssertEqual(view.received.last?.count, 3)

        presenter.didTapCellAction(indexPath: nil)
        XCTAssertTrue(router.sheets.isEmpty)

        presenter.didTapCellAction(indexPath: IndexPath(row: 0, section: 0))
        let unavailable = try XCTUnwrap(router.sheets.last)
        XCTAssertTrue(unavailable.title.hasPrefix("Single "))
        XCTAssertEqual(unavailable.message, R.string.localizable.networkIssueUnavailable(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(unavailable.actions.count, 1)
        unavailable.actions.first?.handler?()
        XCTAssertEqual(interactor.muted, ["single"])

        presenter.didTapCellAction(indexPath: IndexPath(row: 1, section: 0))
        let switchSheet = try XCTUnwrap(router.sheets.last)
        XCTAssertTrue(switchSheet.title.contains("Multi"))
        XCTAssertNil(switchSheet.message)
        XCTAssertEqual(switchSheet.actions.count, 2)
        switchSheet.actions[0].handler?()
        XCTAssertEqual(router.nodeSelections, ["multi"])
        switchSheet.actions[1].handler?()
        XCTAssertEqual(interactor.muted, ["single", "multi"])

        presenter.didTapCellAction(indexPath: IndexPath(row: 2, section: 0))
        XCTAssertEqual(router.accountOptions.last, [.create, .import, .skip])
        router.skip?(missing)
        XCTAssertEqual(interactor.unused, ["missing"])

        presenter.dissmis()
        XCTAssertEqual(router.dismissed, 1)
        presenter.applyLocalization()
        XCTAssertEqual(view.received.count, 2)
    }

    func testPresenterKeepsOnlyKnownChainsFromLaterIssueUpdatesAndTracksWallet() {
        let known = CovJFixture.chain(id: "known", name: "Known", nodeCount: 2)
        let other = CovJFixture.chain(id: "other", name: "Other", nodeCount: 2)
        let account = CovJFixture.chain(id: "account", name: "Account")
        let (presenter, view, _, router) = makePresenter(issues: [.network(chains: [known]), .missingAccount(chains: [account])])
        presenter.didReceive(chainSettings: [])
        presenter.didReceiveChainsIssues(issues: [
            .network(chains: [known, other]),
            .missingAccount(chains: [account, other])
        ])
        XCTAssertEqual(view.received.last?.map(\.chain.chainId), ["known", "account"])

        let unusedWallet = AccountGenerator.generateMetaAccount().replacingUnusedChainIds(["account"])
        presenter.didReceiveWallet(wallet: unusedWallet)
        presenter.didTapCellAction(indexPath: IndexPath(row: 1, section: 0))
        XCTAssertEqual(router.accountOptions.last, [.create, .import])

        let (fresh, freshView, _, _) = makePresenter(issues: [])
        fresh.didReceive(chainSettings: [])
        fresh.didReceiveChainsIssues(issues: [.network(chains: [other])])
        XCTAssertEqual(freshView.received.last?.map(\.chain.chainId), ["other"])
    }

    func testMissingAccountOptionsDependOnUnusedFlagAndRootPhraseChains() {
        let plain = CovJFixture.chain(id: "plain")
        XCTAssertEqual(NetworkIssuesNotificationPresenter.missingAccountOptions(for: plain, unused: false), [.create, .import, .skip])
        XCTAssertEqual(NetworkIssuesNotificationPresenter.missingAccountOptions(for: plain, unused: true), [.create, .import])
        let taira = CovJFixture.chain(id: UniversalWalletRegistry.taira.chainId, name: "Taira")
        XCTAssertEqual(NetworkIssuesNotificationPresenter.missingAccountOptions(for: taira, unused: false), [.import, .skip])
        XCTAssertEqual(NetworkIssuesNotificationPresenter.missingAccountOptions(for: taira, unused: true), [.import])
    }

    func testViewControllerShowsRowsEmptyStateAndForwardsActions() throws {
        let output = CovJIssuesOutput()
        let controller = NetworkIssuesNotificationViewController(output: output, localizationManager: LocalizationManager.shared)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        XCTAssertEqual(output.loads, 1)
        let layout = try XCTUnwrap(controller.view as? NetworkIssuesNotificationViewLayout)
        let table = layout.tableView
        XCTAssertFalse(table.allowsSelection)

        controller.didReceive(viewModel: [])
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 0)
        XCTAssertTrue(controller.shouldDisplayEmptyState)
        let empty = try XCTUnwrap(controller.viewForEmptyState as? ErrorStateView)
        XCTAssertEqual(
            empty.errorDescriptionLabel.text,
            R.string.localizable.networkIssuesEmptyStateTitle(preferredLanguages: locale.rLanguages)
        )
        XCTAssertTrue(empty.retryButton.isHidden)
        XCTAssertTrue(controller.contentViewForEmptyState === layout)

        let rows = NetworkIssuesNotificationViewModelFactory().buildViewModel(
            for: [.network(chains: [CovJFixture.chain(id: "a", name: "Alpha", nodeCount: 2), CovJFixture.chain(id: "b", name: "Beta")]),
                  .missingAccount(chains: [CovJFixture.chain(id: "c", name: "Gamma")])],
            locale: locale,
            chainSettings: []
        )
        controller.didReceive(viewModel: rows)
        XCTAssertFalse(controller.shouldDisplayEmptyState)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 3)
        for row in 0 ..< 3 {
            let indexPath = IndexPath(row: row, section: 0)
            let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: indexPath) as? NetworkIssuesNotificationTableCell)
            controller.tableView(table, willDisplay: cell, forRowAt: indexPath)
            let texts = CovJViewFixture.descendants(UILabel.self, in: cell).compactMap(\.text)
            XCTAssertTrue(texts.contains(rows[row].chainNameTitle))
            XCTAssertTrue(texts.contains(rows[row].issueDescription))
            XCTAssertTrue(cell.delegate === controller)
            cell.prepareForReuse()
        }
        controller.tableView(table, willDisplay: UITableViewCell(), forRowAt: IndexPath(row: 0, section: 0))
        controller.didTapOnAction(with: IndexPath(row: 2, section: 0))
        XCTAssertEqual(output.taps, [IndexPath(row: 2, section: 0)])
        layout.closeButton.sendActions(for: .touchUpInside)
        layout.bottomCloseButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.dismissals, 2)
        controller.applyLocalization()
        XCTAssertEqual(layout.locale, controller.selectedLocale)
    }

    func testCellButtonTitleFollowsIssueKindAndTapReportsIndexPath() throws {
        let cell = NetworkIssuesNotificationTableCell(style: .default, reuseIdentifier: nil)
        let delegate = CovJIssuesCellDelegate()
        cell.delegate = delegate
        let chain = CovJFixture.chain(name: "Kind")
        let kinds: [NetworkIssuesActionButtonType] = [.switchNode(title: "Switch"), .networkUnavailible(title: "Resolve"), .missingAccount(title: "Add")]
        for kind in kinds {
            cell.bind(viewModel: NetworkIssuesNotificationCellViewModel(
                imageViewViewModel: nil, chainNameTitle: "Kind", issueDescription: "Broken", buttonType: kind, chain: chain
            ))
            let buttons = CovJViewFixture.descendants(TriangularedButton.self, in: cell)
            let titles = buttons.compactMap { $0.imageWithTitleView?.title }
            switch kind {
            case let .switchNode(title), let .networkUnavailible(title), let .missingAccount(title):
                XCTAssertTrue(titles.contains(title))
            }
        }
        let button = try XCTUnwrap(CovJViewFixture.descendants(TriangularedButton.self, in: cell).first)
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(delegate.taps.count, 1)
    }

    func testInteractorDeliversSettingsIssuesAndPersistsMute() throws {
        let facade = UserDataStorageTestFacade()
        let settingsRepository = ChainSettingsRepositoryFactory(storageFacade: facade).createRepository()
        let accountRepository = AccountRepositoryFactory(storageFacade: facade).createMetaAccountRepository(for: nil, sortDescriptors: [])
        let center = CovJIssuesCenter()
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = NetworkIssuesNotificationInteractor(
            wallet: wallet,
            accountRepository: AnyDataProviderRepository(accountRepository),
            operationQueue: OperationQueue(),
            eventCenter: EventCenter.shared,
            chainsIssuesCenter: center,
            chainSettingsRepository: AnyDataProviderRepository(settingsRepository)
        )
        let output = CovJIssuesInteractorOutput()
        interactor.setup(with: output)
        XCTAssertEqual(center.listeners.count, 1)
        XCTAssertTrue(CovJWait.until(timeout: 5) { output.settings.count == 1 })
        XCTAssertEqual(output.settings.first, [])

        let chain = CovJFixture.chain(id: "mute-me")
        interactor.handleChainsIssues([.network(chains: [chain])])
        XCTAssertTrue(CovJWait.until { output.issues.count == 1 })

        interactor.mute(chain: chain)
        XCTAssertTrue(CovJWait.until(timeout: 5) { output.settings.count >= 2 && center.forced == 1 })
        XCTAssertEqual(output.settings.last?.first { $0.chainId == "mute-me" }?.issueMuted, true)
    }

    func testRouterBuildsAccountOptionSheetAndSkipsThroughBlock() throws {
        let router = NetworkIssuesNotificationRouter()
        let host = try CovJHostedView()
        defer { host.close() }
        let chain = CovJFixture.chain(id: "router-chain", name: "Router")
        var skipped: [String] = []
        router.presentAccountOptions(
            from: host,
            locale: locale,
            options: [.create, .import, .skip],
            uniqueChainModel: UniqueChainModel(meta: AccountGenerator.generateMetaAccount(), chain: chain)
        ) { skipped.append($0.chainId) }
        let sheet = try XCTUnwrap(host.presented as? SheetAletViewController)
        sheet.loadViewIfNeeded()
        let texts = CovJViewFixture.descendants(UILabel.self, in: sheet.view).compactMap(\.text)
        XCTAssertTrue(texts.contains(R.string.localizable.importSourcePickerTitle(preferredLanguages: locale.rLanguages)))
        router.dismiss(view: host)
        XCTAssertTrue(skipped.isEmpty)
    }
}

final class CovJIssuesCellDelegate: NetworkIssuesNotificationTableCellDelegate {
    var taps: [IndexPath?] = []
    func didTapOnAction(with indexPath: IndexPath?) { taps.append(indexPath) }
}
