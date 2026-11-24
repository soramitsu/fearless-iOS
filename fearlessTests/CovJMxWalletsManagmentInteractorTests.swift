import XCTest
import RobinHood
@testable import fearless

final class CovJMxWalletBalanceAdapter: WalletBalanceSubscriptionAdapterProtocol {
    private(set) var listeners: [WalletBalanceSubscriptionListener] = []
    func subscribeWalletBalance(wallet _: MetaAccountModel, listener _: WalletBalanceSubscriptionListener) {}
    func subscribeWalletsBalances(listener: WalletBalanceSubscriptionListener) { listeners.append(listener) }
    func subscribeChainAssetBalance(wallet _: MetaAccountModel, chainAsset _: ChainAsset, listener _: WalletBalanceSubscriptionListener) {}
    func subscribeChainAssetsBalance(chainAssets _: [ChainAsset], wallet _: MetaAccountModel, listener _: WalletBalanceSubscriptionListener) {}
    func subscribeNetworkManagementBalance(wallet _: MetaAccountModel, listener _: WalletBalanceSubscriptionListener) {}
    func unsubscribe(listener _: WalletBalanceSubscriptionListener) {}
}

final class CovJMxFeatureToggles: FeatureToggleProviderProtocol {
    var failure: Error?
    func fetchConfigOperation() -> BaseOperation<FeatureToggleConfig> {
        let failure = failure
        return ClosureOperation {
            if let failure { throw failure }
            return FeatureToggleConfig(pendulumCaseEnabled: true, nftEnabled: false)
        }
    }
}

final class CovJMxRecordsInspector: StoredWalletRecordsInspecting {
    var failure: Error?
    func fetchReportOperation() -> BaseOperation<StoredWalletRecordsReport> {
        let failure = failure
        return ClosureOperation {
            if let failure { throw failure }
            return StoredWalletRecordsReport(unavailableWalletCount: 3, wallets: [])
        }
    }

    func selectChainAccountOperation(_: ChainAccountSelectionUpdate, walletId _: MetaAccountId) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { throw CovJError("unused") }
    }
}

final class CovJMxWalletsInteractorOutput: WalletsManagmentInteractorOutput {
    var wallets: [Result<[ManagedMetaAccountModel], Error>] = []
    var balances = 0
    var errors: [Error] = []
    var completions = 0
    var configs: [Result<FeatureToggleConfig, Error>?] = []
    var reports: [StoredWalletRecordsReport] = []
    func didReceiveWallets(_ wallets: Result<[ManagedMetaAccountModel], Error>) { self.wallets.append(wallets) }
    func didReceiveWalletBalances(_: Result<[MetaAccountId: WalletBalanceInfo], Error>) { balances += 1 }
    func didReceive(error: Error) { errors.append(error) }
    func didCompleteSelection() { completions += 1 }
    func didReceiveFeatureToggleConfig(result: Result<FeatureToggleConfig, Error>?) { configs.append(result) }
    func didReceiveWalletRecordsReport(_ report: StoredWalletRecordsReport) { reports.append(report) }
}

final class CovJMxWalletsManagmentInteractorTests: XCTestCase {
    private var adapter = CovJMxWalletBalanceAdapter()
    private var toggles = CovJMxFeatureToggles()
    private var inspector = CovJMxRecordsInspector()
    private var output = CovJMxWalletsInteractorOutput()
    private var eventCenter = EventCenter()

    override func setUp() {
        super.setUp()
        adapter = CovJMxWalletBalanceAdapter()
        toggles = CovJMxFeatureToggles()
        inspector = CovJMxRecordsInspector()
        output = CovJMxWalletsInteractorOutput()
        eventCenter = EventCenter()
    }

    func testSetupLoadsWalletsBalancesTogglesAndRecordsReport() {
        let wallet = ManagedMetaAccountModel(info: AccountGenerator.generateMetaAccount(), isSelected: true)
        let interactor = makeInteractor(repository: CovJMemoryRepository([wallet]))

        interactor.setup(with: output)

        XCTAssertTrue(CovJWait.until(timeout: 5) {
            self.output.wallets.count == 1 && self.output.configs.count == 1 && self.output.reports.count == 1
        })
        guard case let .success(items) = output.wallets.first else {
            return XCTFail("Expected wallets")
        }
        XCTAssertEqual(items, [wallet])
        XCTAssertEqual(output.reports.first?.unavailableWalletCount, 3)
        guard case let .success(config)?? = output.configs.first else {
            return XCTFail("Expected a feature toggle config")
        }
        XCTAssertEqual(config.pendulumCaseEnabled, true)
        XCTAssertEqual(adapter.listeners.count, 1)
        XCTAssertTrue(adapter.listeners.first === interactor)
        guard case .wallets = interactor.type else {
            return XCTFail("Expected the wallets listener type")
        }

        interactor.handle(result: .failure(CovJError()))
        XCTAssertEqual(output.balances, 1)
    }

    func testFailuresAreForwardedAndAMissingReportIsSkipped() {
        let repository = CovJMemoryRepository<ManagedMetaAccountModel>()
        repository.failure = CovJError("db")
        toggles.failure = CovJError("toggles")
        inspector.failure = CovJError("report")
        let interactor = makeInteractor(repository: repository)

        interactor.setup(with: output)

        XCTAssertTrue(CovJWait.until(timeout: 5) { self.output.wallets.count == 1 && self.output.configs.count == 1 })
        CovJWait.drain(0.1)
        guard case let .failure(error) = output.wallets.first else {
            return XCTFail("Expected a failure")
        }
        XCTAssertEqual(error as? CovJError, CovJError("db"))
        guard case .failure?? = output.configs.first else {
            return XCTFail("Expected a failed config")
        }
        XCTAssertTrue(output.reports.isEmpty)
    }

    func testWalletEventsAndExplicitRefreshReloadTheList() {
        let interactor = makeInteractor(repository: CovJMemoryRepository([ManagedMetaAccountModel(info: AccountGenerator.generateMetaAccount())]))
        interactor.setup(with: output)
        XCTAssertTrue(CovJWait.until(timeout: 5) { self.output.wallets.count == 1 })

        interactor.fetchWalletsFromRepo()
        XCTAssertTrue(CovJWait.until(timeout: 5) { self.output.wallets.count == 2 })

        eventCenter.notify(with: WalletNameChanged(wallet: AccountGenerator.generateMetaAccount()))
        XCTAssertTrue(CovJWait.until(timeout: 5) { self.output.wallets.count == 3 })

        eventCenter.notify(with: MetaAccountModelChangedEvent(account: AccountGenerator.generateMetaAccount()))
        XCTAssertTrue(CovJWait.until(timeout: 5) { self.output.wallets.count == 4 })
        XCTAssertTrue(CovJWait.until(timeout: 5) { self.output.reports.count == 4 })
    }

    func testSelectionWithoutSavingCompletesImmediately() {
        let interactor = makeInteractor(repository: CovJMemoryRepository(), shouldSaveSelected: false)
        interactor.setup(with: output)

        interactor.select(wallet: ManagedMetaAccountModel(info: AccountGenerator.generateMetaAccount()))

        XCTAssertEqual(output.completions, 1)
        XCTAssertTrue(output.errors.isEmpty)
    }

    func testSelectingAWalletMissingFromStorageReportsTheError() {
        let interactor = makeInteractor(repository: CovJMemoryRepository(), shouldSaveSelected: true)
        interactor.setup(with: output)

        interactor.select(wallet: ManagedMetaAccountModel(info: AccountGenerator.generateMetaAccount()))

        XCTAssertTrue(CovJWait.until(timeout: 5) { self.output.errors.count + self.output.completions > 0 })
        XCTAssertEqual(output.errors.count, 1)
        XCTAssertEqual(output.completions, 0)
    }

    private func makeInteractor(
        repository: CovJMemoryRepository<ManagedMetaAccountModel>,
        shouldSaveSelected: Bool = false
    ) -> WalletsManagmentInteractor {
        WalletsManagmentInteractor(
            shouldSaveSelected: shouldSaveSelected,
            walletBalanceSubscriptionAdapter: adapter,
            metaAccountRepository: AnyDataProviderRepository(repository),
            operationQueue: OperationQueue(),
            settings: SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue()),
            eventCenter: eventCenter,
            featureToggleService: toggles,
            walletRecordsInspector: inspector
        )
    }
}
