import XCTest
import UIKit
import RobinHood
import SoraFoundation
import FearlessWalletConnect
import SSFModels
@testable import fearless

final class CovHWMCOutputSpy: WalletMainContainerInteractorOutput {
    private(set) var accounts: [MetaAccountModel] = []
    private(set) var filters: [NetworkManagmentFilter] = []
    private(set) var errors: [Error] = []
    private(set) var controllerIssues: [(ControllerAccountIssue, Bool)] = []
    private(set) var stashAddresses: [String] = []
    private(set) var nftAvailability: [Bool] = []
    private(set) var notices: [[StoredWalletRecordsNotice]] = []
    private(set) var noPasswordAccounts: [[UniversalWalletNoPasswordAccount]] = []
    private(set) var outcomes: [[UniversalWalletSlot: UniversalWalletSwitchOutcome]] = []
    private(set) var arrivals: [[UniversalWalletOldAddressArrival]] = []
    private(set) var syncUpdates: [WalletSyncUpdate] = []

    func didReceiveAccount(_ account: MetaAccountModel) { accounts.append(account) }
    func didReceiveSelected(tuple: (select: NetworkManagmentFilter, chains: [ChainModel])) { filters.append(tuple.select) }
    func didReceiveError(_ error: Error) { errors.append(error) }
    func didReceiveControllerAccountIssue(issue: ControllerAccountIssue, hasStashItem: Bool) {
        controllerIssues.append((issue, hasStashItem))
    }

    func didReceiveStashAccountIssue(address: String) { stashAddresses.append(address) }
    func didReceiveNftAvailability(isNftAvailable: Bool) { nftAvailability.append(isNftAvailable) }
    func didReceiveStoredWalletRecordsNotices(_ notices: [StoredWalletRecordsNotice]) { self.notices.append(notices) }
    func didReceiveUniversalWalletNoPasswordAccounts(_ accounts: [UniversalWalletNoPasswordAccount]) {
        noPasswordAccounts.append(accounts)
    }

    func didReceiveUniversalWalletSwitchOutcomes(
        _ outcomes: [UniversalWalletSlot: UniversalWalletSwitchOutcome],
        for _: [UniversalWalletNoPasswordAccount]
    ) {
        self.outcomes.append(outcomes)
    }

    func didReceiveUniversalWalletOldAddressArrivals(_ arrivals: [UniversalWalletOldAddressArrival]) {
        self.arrivals.append(arrivals)
    }

    func didReceive(syncUpdate: WalletSyncUpdate) { syncUpdates.append(syncUpdate) }
}

final class CovHWMCDeprecationStub: DeprecatedControllerStashAccountCheckServiceProtocol {
    var issue: DeprecatedAccountIssue?
    var stashItems: [StashItem] = []
    func checkAccountDeprecations(wallet _: MetaAccountModel) async throws -> DeprecatedAccountIssue? { issue }
    func checkStashItems() async throws -> [StashItem] { stashItems }
}

final class CovHWMCWalletConnectStub: WalletConnectService {
    var error: Error?
    private(set) var uris: [String] = []
    func setup() {}
    func throttle() {}
    func set(listener _: WalletConnectServiceDelegate) {}
    func connect(uri: String) async throws {
        uris.append(uri)
        if let error { throw error }
    }

    func disconnect(topic _: String) async throws {}
    func disconnectAll() async throws {}
    func getSessions() -> [Session] { [] }
    func isPending(request _: Request) async -> Bool { false }
    func legacySessionsNeedingReconnect() -> [WalletConnectLegacySession] { [] }
    func submit(proposalDecision _: WalletConnectProposalDecision) async throws {}
    func submit(signDecision _: WalletConnectSignDecision) async throws {}
}

struct CovHWMCFeatures: FeatureToggleProviderProtocol {
    func fetchConfigOperation() -> BaseOperation<FeatureToggleConfig> {
        ClosureOperation { FeatureToggleConfig.defaultConfig }
    }
}

final class CovHWMCRecordsInspector: StoredWalletRecordsInspecting {
    var report: StoredWalletRecordsReport?

    func fetchReportOperation() -> BaseOperation<StoredWalletRecordsReport> {
        let report = self.report
        return ClosureOperation {
            guard let report else { throw NSError(domain: "cov-h-records", code: 1) }
            return report
        }
    }

    func selectChainAccountOperation(_: ChainAccountSelectionUpdate, walletId _: MetaAccountId) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { throw NSError(domain: "cov-h-records", code: 2) }
    }
}

final class CovHWMCNoticeTracker: StoredWalletRecordsNoticeTracking {
    var pending: [StoredWalletRecordsNotice] = []
    private(set) var acknowledged: [String] = []
    func pendingNotices(for _: StoredWalletRecordsReport) -> [StoredWalletRecordsNotice] { pending }
    func acknowledgeRecordsNotShown(in _: StoredWalletRecordsReport) { acknowledged.append("records") }
    func acknowledgeStoredChainAccounts(in _: StoredWalletRecordsReport) { acknowledged.append("accounts") }
    func acknowledgeStoredChainAccounts(of _: MetaAccountId, in _: StoredWalletRecordsReport) { acknowledged.append("walletAccounts") }
}

/// A wallet without root words; counts how often a check asked for them.
final class CovHWMCMnemonicCounter: UniversalWalletRootMnemonicProviding {
    private let lock = NSLock()
    private var storedCount = 0
    var reads: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedCount
    }

    private func bump() {
        lock.lock()
        storedCount += 1
        lock.unlock()
    }

    func rootMnemonic(for _: MetaAccountModel) throws -> String? {
        bump()
        return nil
    }

    func rootSecret(for _: MetaAccountModel) throws -> UniversalWalletSecret? {
        bump()
        return nil
    }
}

final class CovHWMCInteractorHarness {
    let output = CovHWMCOutputSpy()
    let eventCenter = EventCenter()
    let deprecation = CovHWMCDeprecationStub()
    let walletConnect = CovHWMCWalletConnectStub()
    let inspector = CovHWMCRecordsInspector()
    let tracker = CovHWMCNoticeTracker()
    let switcherWords = CovHWMCMnemonicCounter()
    let checkerWords = CovHWMCMnemonicCounter()
    let defaults = CovHAssetListFixture.defaults()
    let watched: UniversalWalletWatchedAccountsStore
    let noticeTracker: UniversalWalletPasswordNoticeTracker
    let wallet: MetaAccountModel
    let interactor: WalletMainContainerInteractor
    let unlock: WalletAuthorizedUnlock

    /// `unlocked`: the user has just unlocked the app, so checks that read the wallet's words run.
    /// `watching`: the wallet has a watched network, the only kind whose words the check reads.
    init(
        wallet: MetaAccountModel = AccountGenerator.generateMetaAccount(),
        unlocked: Bool = true,
        watching: Set<UniversalWalletSlot> = [.solana],
        unlockNotifications: NotificationCenter = NotificationCenter()
    ) {
        self.wallet = wallet
        watched = UniversalWalletWatchedAccountsStore(userDefaults: defaults)
        watched.watch(watching, in: wallet.metaId)
        noticeTracker = UniversalWalletPasswordNoticeTracker(userDefaults: defaults)
        unlock = WalletAuthorizedUnlock(notificationCenter: unlockNotifications)
        if unlocked {
            unlock.recordUnlock()
        }
        let facade = UserDataStorageTestFacade()
        interactor = WalletMainContainerInteractor(
            accountRepository: AnyDataProviderRepository(
                AccountRepositoryFactory(storageFacade: facade).createMetaAccountRepository(for: nil, sortDescriptors: [])
            ),
            chainRepository: AnyDataProviderRepository(
                ChainRepositoryFactory(storageFacade: SubstrateStorageTestFacade()).createRepository()
            ),
            wallet: wallet,
            operationQueue: OperationQueue(),
            eventCenter: eventCenter,
            deprecatedAccountsCheckService: deprecation,
            applicationHandler: ApplicationHandler(),
            walletConnectService: walletConnect,
            featureToggleService: CovHWMCFeatures(),
            walletRecordsInspector: inspector,
            walletRecordsNoticeTracker: tracker,
            passwordSwitcher: UniversalWalletPasswordSwitcher(mnemonicProvider: switcherWords),
            passwordNoticeTracker: noticeTracker,
            watchedAccounts: watched,
            watchedAccountsChecker: UniversalWalletWatchedAccountsChecker(mnemonicProvider: checkerWords, watchedAccounts: watched),
            authorizedUnlock: unlock
        )
    }

    func setup() {
        interactor.setup(with: output)
        CovHAssetListFixture.spin { !output.nftAvailability.isEmpty && !output.filters.isEmpty && checkerWords.reads > 0 }
        // Let the first watched-address check finish on the main actor before the next one starts.
        CovHAssetListFixture.spin(timeout: 0.3) { false }
        CovHAssetListFixture.drainMain()
    }
}

final class CovHWMCInteractorTests: XCTestCase {
    func testSetupReadsTheStoredFilterNftsRecordsAndPasswordState() throws {
        let harness = CovHWMCInteractorHarness(wallet: AccountGenerator.generateMetaAccount().replacingNetworkManagmentFilter("popular"))
        harness.inspector.report = StoredWalletRecordsReport(unavailableWalletCount: 1, wallets: [])
        harness.tracker.pending = [.recordsNotShown(wallets: 1, chainAccounts: 0)]

        harness.setup()
        CovHAssetListFixture.spin { !harness.output.notices.isEmpty && harness.switcherWords.reads > 0 }

        guard case .popular = try XCTUnwrap(harness.output.filters.first) else { return XCTFail("Expected the stored filter") }
        XCTAssertEqual(harness.output.nftAvailability, [FeatureToggleConfig.defaultConfig.nftEnabled == true])
        XCTAssertEqual(harness.output.notices, [[.recordsNotShown(wallets: 1, chainAccounts: 0)]])
        XCTAssertGreaterThan(harness.switcherWords.reads, 0, "The password check read the wallet's words")
        XCTAssertTrue(harness.output.noPasswordAccounts.isEmpty, "A wallet without words has nothing to switch")

        harness.interactor.acknowledge(.recordsNotShown(wallets: 1, chainAccounts: 0))
        harness.interactor.acknowledge(.storedChainAccounts(walletIds: [], walletNames: []))
        XCTAssertEqual(harness.tracker.acknowledged, ["records", "accounts"])
    }

    func testUnreadableRecordsAreNeverAcknowledged() {
        let harness = CovHWMCInteractorHarness()
        harness.setup()
        CovHAssetListFixture.drainMain()

        harness.interactor.acknowledge(.recordsNotShown(wallets: 1, chainAccounts: 0))

        XCTAssertTrue(harness.tracker.acknowledged.isEmpty)
        XCTAssertTrue(harness.output.notices.isEmpty)
        guard case .all = harness.output.filters.first else { return XCTFail("A wallet without a filter shows all networks") }
    }

    func testPasswordNoticeShownBeforeIsNotCheckedAgain() {
        let harness = CovHWMCInteractorHarness()
        harness.noticeTracker.markShown(for: harness.wallet.metaId)

        harness.setup()

        XCTAssertEqual(harness.switcherWords.reads, 0)
    }

    func testAcknowledgementsAreRemembered() {
        let harness = CovHWMCInteractorHarness()
        let arrival = UniversalWalletOldAddressArrival(slot: .solana, oldAddress: "old-sol", balance: "1 SOL")

        harness.interactor.acknowledgeUniversalWalletPasswordNotice()
        harness.interactor.acknowledgeOldAddressArrivals([arrival])

        XCTAssertTrue(harness.noticeTracker.wasShown(for: harness.wallet.metaId))
        XCTAssertTrue(harness.watched.unnotified([arrival], in: harness.wallet.metaId).isEmpty)
    }

    func testSwitchWithoutWordsReportsUncheckedOutcomes() {
        let harness = CovHWMCInteractorHarness()
        harness.interactor.setup(with: harness.output)
        let account = UniversalWalletNoPasswordAccount(slot: .solana, oldAddress: "old", newAddress: "new", newPublicKey: Data([1]))

        harness.interactor.switchNoPasswordAccounts([account])
        CovHAssetListFixture.spin { !harness.output.outcomes.isEmpty }

        XCTAssertEqual(harness.output.outcomes, [[.solana: .unchecked]])
    }

    func testWalletConnectPairingIsForwarded() async throws {
        let harness = CovHWMCInteractorHarness()
        try await harness.interactor.walletConnect(uri: "wc:cov-h")
        harness.walletConnect.error = WalletConnectServiceError.unavailable
        do {
            try await harness.interactor.walletConnect(uri: "wc:failing")
            XCTFail("Expected the pairing error")
        } catch {
            XCTAssertNotNil(error as? WalletConnectServiceError)
        }
        XCTAssertEqual(harness.walletConnect.uris, ["wc:cov-h", "wc:failing"])
    }

    func testFilterChangeOfTheSameWalletReadsTheFilterAgain() {
        let harness = CovHWMCInteractorHarness()
        harness.setup()
        let filters = harness.output.filters.count

        harness.interactor.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: AccountGenerator.generateMetaAccount()))
        XCTAssertTrue(harness.output.accounts.isEmpty)

        let favourites = harness.wallet.replacingNetworkManagmentFilter("favourite")
        harness.interactor.processMetaAccountChanged(event: MetaAccountModelChangedEvent(account: favourites))
        CovHAssetListFixture.spin { harness.output.filters.count > filters }

        XCTAssertEqual(harness.output.accounts.map(\.metaId), [harness.wallet.metaId])
        guard case .favourite = harness.output.filters.last else { return XCTFail("Expected the new filter") }
    }

    func testSyncEventsAndDeprecatedAccountsReachTheOutput() throws {
        let harness = CovHWMCInteractorHarness()
        harness.setup()
        let asset = CovHAssetListFixture.chainAsset()
        harness.deprecation.issue = .controller(issue: ControllerAccountIssue(chainAsset: asset, wallet: harness.wallet, address: "controller"))
        harness.deprecation.stashItems = [StashItem(stash: "stash", controller: "controller")]

        harness.interactor.processChainSyncDidStart(event: ChainSyncDidStart())
        harness.interactor.processChainSyncDidFail(event: ChainSyncDidFail(error: NSError(domain: "cov-h", code: 3)))
        harness.interactor.processChainReconnecting(event: ChainReconnectingEvent(chain: asset.chain, state: .connected))
        harness.interactor.processChainSyncDidComplete(event: ChainSyncDidComplete(newOrUpdatedChains: [], removedChains: []))
        CovHAssetListFixture.spin { !harness.output.controllerIssues.isEmpty }

        XCTAssertEqual(harness.output.syncUpdates, [
            .catalog(running: true),
            .catalogFailed,
            .connection(chainId: asset.chain.chainId, .connected),
            .catalog(running: false)
        ])
        let issue = try XCTUnwrap(harness.output.controllerIssues.first)
        XCTAssertEqual(issue.0.address, "controller")
        XCTAssertTrue(issue.1)

        harness.deprecation.issue = .stash(address: "stash-address")
        let checks = harness.checkerWords.reads
        harness.interactor.didReceiveWillEnterForeground(notification: Notification(name: UIApplication.willEnterForegroundNotification))
        CovHAssetListFixture.spin { !harness.output.stashAddresses.isEmpty && harness.checkerWords.reads > checks }
        XCTAssertEqual(harness.output.stashAddresses, ["stash-address"])
        XCTAssertGreaterThan(harness.checkerWords.reads, checks, "Coming back to the app checks the watched addresses")
    }

    func testPortfolioRefreshChecksTheWatchedAddressesAgain() {
        let harness = CovHWMCInteractorHarness()
        harness.setup()
        let checks = harness.checkerWords.reads

        NotificationCenter.default.post(name: .universalWalletPortfolioRefreshed, object: nil)
        CovHAssetListFixture.spin { harness.checkerWords.reads > checks }

        XCTAssertGreaterThan(harness.checkerWords.reads, checks)
    }

    func testRefreshAndForegroundOutsideAnUnlockReadNoWords() {
        let harness = CovHWMCInteractorHarness(unlocked: false)
        harness.interactor.setup(with: harness.output)
        CovHAssetListFixture.spin { !harness.output.nftAvailability.isEmpty && !harness.output.filters.isEmpty }

        NotificationCenter.default.post(name: .universalWalletPortfolioRefreshed, object: nil)
        harness.interactor.didReceiveWillEnterForeground(notification: Notification(name: UIApplication.willEnterForegroundNotification))
        CovHAssetListFixture.spin(timeout: 0.3) { false }
        CovHAssetListFixture.drainMain()

        XCTAssertEqual(harness.checkerWords.reads, 0, "A refresh or foreground alone never reads the words")
        XCTAssertEqual(harness.switcherWords.reads, 0, "The password notice waits for an unlock")
    }

    func testWalletWithoutWatchedNetworksIsNotCheckedEvenRightAfterUnlock() {
        let harness = CovHWMCInteractorHarness(watching: [])
        harness.interactor.setup(with: harness.output)
        CovHAssetListFixture.spin { harness.switcherWords.reads > 0 }

        NotificationCenter.default.post(name: .universalWalletPortfolioRefreshed, object: nil)
        CovHAssetListFixture.spin(timeout: 0.3) { false }
        CovHAssetListFixture.drainMain()

        XCTAssertEqual(harness.checkerWords.reads, 0)
    }

    func testUnlockRunsTheChecksThatWaited() {
        let notifications = NotificationCenter.default
        let harness = CovHWMCInteractorHarness(unlocked: false, unlockNotifications: notifications)
        harness.interactor.setup(with: harness.output)
        CovHAssetListFixture.spin(timeout: 0.3) { false }
        XCTAssertEqual(harness.checkerWords.reads, 0)
        XCTAssertEqual(harness.switcherWords.reads, 0)

        harness.unlock.recordUnlock()
        CovHAssetListFixture.spin { harness.checkerWords.reads > 0 && harness.switcherWords.reads > 0 }

        XCTAssertGreaterThan(harness.checkerWords.reads, 0)
        XCTAssertGreaterThan(harness.switcherWords.reads, 0)
    }

    func testSelectedWalletChangeFollowsTheStoredSelection() {
        let harness = CovHWMCInteractorHarness()
        harness.setup()
        let selected = SelectedWalletSettings.shared.value

        harness.interactor.processSelectedAccountChanged(event: SelectedAccountChanged(account: AccountGenerator.generateMetaAccount()))
        CovHAssetListFixture.drainMain()

        if let selected {
            XCTAssertEqual(harness.output.accounts.last?.metaId, selected.metaId)
            XCTAssertEqual(harness.output.arrivals.count, selected.metaId == harness.wallet.metaId ? 0 : 1)
        } else {
            XCTAssertTrue(harness.output.accounts.isEmpty, "Without a stored selection nothing changes")
        }
    }
}
