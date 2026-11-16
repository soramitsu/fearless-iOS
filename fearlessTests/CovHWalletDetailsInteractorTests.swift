import XCTest
import RobinHood
import SSFModels
@testable import fearless

final class CovHWalletDetailsOutputSpy: WalletDetailsInteractorOutputProtocol {
    var chains: [[ChainModel]] = []
    var exportOptions: [[ExportOption]] = []
    var errors: [Error] = []
    var flows: [WalletDetailsFlow] = []
    var storedAccounts: [[ChainAccountModel]] = []
    var noPasswordAccounts: [[UniversalWalletNoPasswordAccount]] = []
    var outcomes: [[UniversalWalletSlot: UniversalWalletSwitchOutcome]] = []

    func didReceive(chains: [ChainModel]) { self.chains.append(chains) }
    func didReceiveExportOptions(options: [ExportOption], for _: ChainAccountInfo) { exportOptions.append(options) }
    func didReceive(error: Error) { errors.append(error) }
    func didReceive(updatedFlow: WalletDetailsFlow) { flows.append(updatedFlow) }
    func didReceive(storedChainAccounts: [ChainAccountModel]) { storedAccounts.append(storedChainAccounts) }
    func didReceive(noPasswordAccounts: [UniversalWalletNoPasswordAccount]) { self.noPasswordAccounts.append(noPasswordAccounts) }
    func didReceive(switchOutcomes: [UniversalWalletSlot: UniversalWalletSwitchOutcome], for _: [UniversalWalletNoPasswordAccount]) {
        outcomes.append(switchOutcomes)
    }
}

final class CovHWalletDetailsInspectorStub: StoredWalletRecordsInspecting {
    var report = StoredWalletRecordsReport.empty
    var selectionResult: Result<MetaAccountModel, Error> = .failure(NSError(domain: "select", code: 1))
    var updates: [ChainAccountSelectionUpdate] = []

    func fetchReportOperation() -> BaseOperation<StoredWalletRecordsReport> {
        let report = report
        return ClosureOperation { report }
    }

    func selectChainAccountOperation(_ update: ChainAccountSelectionUpdate, walletId _: MetaAccountId) -> BaseOperation<MetaAccountModel> {
        updates.append(update)
        let result = selectionResult
        return ClosureOperation { try result.get() }
    }
}

final class CovHWalletDetailsTrackerSpy: StoredWalletRecordsNoticeTracking {
    var acknowledgedWalletIds: [MetaAccountId] = []
    func pendingNotices(for _: StoredWalletRecordsReport) -> [StoredWalletRecordsNotice] { [] }
    func acknowledgeRecordsNotShown(in _: StoredWalletRecordsReport) {}
    func acknowledgeStoredChainAccounts(in _: StoredWalletRecordsReport) {}
    func acknowledgeStoredChainAccounts(of walletId: MetaAccountId, in _: StoredWalletRecordsReport) { acknowledgedWalletIds.append(walletId) }
}

final class CovHWalletDetailsMnemonicStub: UniversalWalletRootMnemonicProviding {
    func rootMnemonic(for _: MetaAccountModel) throws -> String? { throw NSError(domain: "no-secret", code: 1) }
    func rootSecret(for _: MetaAccountModel) throws -> UniversalWalletSecret? { throw NSError(domain: "no-secret", code: 1) }
}

final class CovHWalletDetailsInteractorContext {
    let output = CovHWalletDetailsOutputSpy()
    let eventCenter = CovHChainAccountEventCenterSpy()
    let inspector = CovHWalletDetailsInspectorStub()
    let tracker = CovHWalletDetailsTrackerSpy()
    let exportOptions = CovHChainAccountExportOptionsStub()
    let wallet: MetaAccountModel
    let interactor: WalletDetailsInteractor

    init(flow: WalletDetailsFlow) {
        wallet = flow.wallet
        let chainsRepository = ChainRepositoryFactory(storageFacade: SubstrateStorageTestFacade()).createRepository()
        interactor = WalletDetailsInteractor(
            flow: flow,
            chainsRepository: AnyDataProviderRepository(chainsRepository),
            operationManager: OperationManager(),
            eventCenter: eventCenter,
            repository: AccountRepositoryFactory.createRepository(for: UserDataStorageTestFacade()),
            availableExportOptionsProvider: exportOptions,
            walletRecordsInspector: inspector,
            walletRecordsNoticeTracker: tracker,
            selectedWalletSettings: SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue()),
            passwordSwitcher: UniversalWalletPasswordSwitcher(mnemonicProvider: CovHWalletDetailsMnemonicStub())
        )
        interactor.presenter = output
    }

    convenience init() {
        self.init(flow: .normal(wallet: CovHChainAccountFixture.wallet()))
    }
}

final class CovHWalletDetailsInteractorTests: XCTestCase {
    func testNormalSetupLoadsChainsStoredAccountsAndPasswordAccounts() {
        let context = CovHWalletDetailsInteractorContext()
        let alternative = CovHWalletDetailsFixture.storedAccount(for: CovHChainAccountFixture.chain())
        context.inspector.report = StoredWalletRecordsReport(
            unavailableWalletCount: 0,
            wallets: [.init(metaId: context.wallet.metaId, name: context.wallet.name, alternatives: [alternative], unusable: [])]
        )
        XCTAssertEqual(context.eventCenter.observers.count, 1)
        context.interactor.setup()
        CovHChainAccountFixture.spin(timeout: 5) {
            !context.output.chains.isEmpty && !context.output.storedAccounts.isEmpty && !context.output.noPasswordAccounts.isEmpty
        }
        XCTAssertEqual(context.output.chains.first?.count, 0)
        XCTAssertEqual(context.output.storedAccounts.first, [alternative])
        XCTAssertEqual(context.output.noPasswordAccounts.first?.count, 0)
        XCTAssertTrue(context.tracker.acknowledgedWalletIds.isEmpty, "loading the screen acknowledges nothing")
    }

    func testExportSetupListsTheExportedChains() {
        let wallet = CovHChainAccountFixture.wallet()
        let chain = CovHChainAccountFixture.chain()
        let account = CovHWalletDetailsFixture.chainAccountResponse(for: chain, wallet: wallet, isChainAccount: false)
        let context = CovHWalletDetailsInteractorContext(flow: .export(wallet: wallet, accounts: [ChainAccountInfo(chain: chain, account: account)]))
        context.interactor.setup()
        XCTAssertEqual(context.output.chains.first?.map(\.chainId), [chain.chainId])
    }

    func testExportOptionsForUnreadableKnownAndUnknownAccounts() throws {
        let context = CovHWalletDetailsInteractorContext()
        let broken = ChainAccountResponse(
            chainId: UniversalWalletRegistry.solanaMainnet.chainId, accountId: Data([1]), publicKey: Data([1]), name: "broken",
            cryptoType: .ed25519, addressPrefix: 0, isEthereumBased: false, isChainAccount: true, walletId: context.wallet.metaId
        )
        context.interactor.getAvailableExportOptions(for: ChainAccountInfo(chain: UniversalWalletRegistry.solanaMainnetChainModel, account: broken))
        XCTAssertEqual(context.output.errors.count, 1)

        let chain = CovHChainAccountFixture.chain()
        let native = try XCTUnwrap(context.wallet.fetch(for: chain.accountRequest()))
        context.exportOptions.options = [.mnemonic, .seed]
        context.interactor.getAvailableExportOptions(for: ChainAccountInfo(chain: chain, account: native))
        XCTAssertEqual(context.output.exportOptions.last, [.mnemonic, .seed])
        XCTAssertNil(context.exportOptions.requests.last?.0)

        let foreign = CovHWalletDetailsFixture.chainAccountResponse(for: chain, wallet: context.wallet, isChainAccount: true)
        context.interactor.getAvailableExportOptions(for: ChainAccountInfo(chain: chain, account: foreign))
        XCTAssertEqual(context.output.exportOptions.last, [.keystore])
        XCTAssertEqual(context.output.exportOptions.count, 2)
    }

    func testSelectingAChainAccountRefreshesFlowAcknowledgesAndAnnounces() {
        let context = CovHWalletDetailsInteractorContext()
        let chain = CovHChainAccountFixture.chain()
        let selected = CovHChainAccountFixture.wallet()
        context.inspector.selectionResult = .success(selected)
        context.interactor.selectChainAccount(.walletAccount, chain: chain)
        XCTAssertEqual(context.inspector.updates, [ChainAccountSelectionUpdate(chainId: chain.chainId, selection: .walletAccount)])
        CovHChainAccountFixture.spin(timeout: 5) { !context.output.storedAccounts.isEmpty && !context.eventCenter.events.isEmpty }
        guard case let .normal(wallet) = context.output.flows.first else {
            return XCTFail("The normal flow follows the stored wallet")
        }
        XCTAssertEqual(wallet.metaId, selected.metaId)
        XCTAssertEqual(context.tracker.acknowledgedWalletIds, [selected.metaId])
        XCTAssertTrue(context.eventCenter.events.first is MetaAccountModelChangedEvent, "a wallet that is not selected is announced as changed")
    }

    func testFailedSelectionReportsTheError() {
        let context = CovHWalletDetailsInteractorContext()
        context.interactor.selectChainAccount(.walletAccount, chain: CovHChainAccountFixture.chain())
        CovHChainAccountFixture.spin(timeout: 5) { !context.output.errors.isEmpty }
        XCTAssertEqual((context.output.errors.first as NSError?)?.domain, "select")
        XCTAssertTrue(context.output.flows.isEmpty)
    }

    func testSelectedAccountChangeUpdatesOnlyTheNormalFlow() {
        let context = CovHWalletDetailsInteractorContext()
        let replacement = CovHChainAccountFixture.wallet()
        context.interactor.processSelectedAccountChanged(event: SelectedAccountChanged(account: replacement))
        CovHChainAccountFixture.spin { !context.output.flows.isEmpty }
        XCTAssertEqual(context.output.flows.first?.wallet.metaId, replacement.metaId)

        let wallet = CovHChainAccountFixture.wallet()
        let export = CovHWalletDetailsInteractorContext(flow: .export(wallet: wallet, accounts: []))
        export.interactor.processSelectedAccountChanged(event: SelectedAccountChanged(account: replacement))
        CovHChainAccountFixture.spin(timeout: 0.3) { false }
        XCTAssertTrue(export.output.flows.isEmpty)
    }

    func testPasswordSwitchWithoutSecretsReportsUncheckedOutcome() {
        let context = CovHWalletDetailsInteractorContext()
        let account = UniversalWalletNoPasswordAccount(slot: .solana, oldAddress: "old", newAddress: "new", newPublicKey: Data([1]))
        context.interactor.switchToPasswordAccount(account)
        CovHChainAccountFixture.spin(timeout: 5) { !context.output.outcomes.isEmpty }
        XCTAssertEqual(context.output.outcomes.first, [.solana: .unchecked])
        XCTAssertTrue(context.output.flows.isEmpty, "an unchanged wallet is not saved")
    }
}
