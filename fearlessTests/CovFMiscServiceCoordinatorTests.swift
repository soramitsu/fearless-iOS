import FearlessWalletConnect
import SSFModels
import XCTest
@testable import fearless

final class CovFMiscServiceCoordinatorTests: XCTestCase {
    func testAccountChangeUpdatesServicesAndRetriesProvisioningOnceTheLastAttemptFinished() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let fixture = try CovFMiscCoordinatorFixture(selected: wallet, mnemonic: CovFMiscMnemonic(error: nil))
        fixture.coordinator.updateOnAccountChange()
        XCTAssertEqual(fixture.accountInfo.updates, [wallet.metaId])
        XCTAssertEqual(fixture.assets.updates, [wallet.metaId])
        try covFMiscEventually { fixture.mnemonic.calls == 1 }
        try covFMiscEventually {
            fixture.coordinator.updateOnAccountChange()
            return fixture.mnemonic.calls >= 2
        }
        XCTAssertEqual(fixture.mnemonic.wallets.first, wallet.metaId)
    }

    func testFailedRootLookupReleasesProvisioningForTheNextChange() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let fixture = try CovFMiscCoordinatorFixture(selected: wallet, mnemonic: CovFMiscMnemonic(error: NSError(domain: "keychain", code: 1)))
        fixture.coordinator.updateOnAccountChange()
        try covFMiscEventually { fixture.mnemonic.calls == 1 }
        try covFMiscEventually {
            fixture.coordinator.updateOnAccountChange()
            return fixture.mnemonic.calls >= 2
        }
    }

    func testWithoutSelectedWalletNothingIsUpdated() throws {
        let fixture = try CovFMiscCoordinatorFixture(selected: nil, mnemonic: CovFMiscMnemonic(error: nil))
        fixture.coordinator.updateOnAccountChange()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertTrue(fixture.accountInfo.updates.isEmpty)
        XCTAssertTrue(fixture.assets.updates.isEmpty)
        XCTAssertEqual(fixture.mnemonic.calls, 0)
    }

    func testThrottleStopsEveryOwnedService() throws {
        let fixture = try CovFMiscCoordinatorFixture(selected: nil, mnemonic: CovFMiscMnemonic(error: nil))
        fixture.coordinator.throttle()
        XCTAssertEqual(fixture.phishing.throttles, 1)
        XCTAssertEqual(fixture.accountInfo.throttles, 1)
        XCTAssertEqual(fixture.walletConnect.throttles, 1)
        XCTAssertEqual(fixture.assets.throttles, 1)
        XCTAssertEqual(fixture.phishing.setups + fixture.accountInfo.setups + fixture.assets.setups, 0)
    }
}

private final class CovFMiscCoordinatorFixture {
    let accountInfo = CovFMiscAccountInfoService()
    let phishing = CovFMiscApplicationService()
    let walletConnect = CovFMiscWalletConnect()
    let assets = CovFMiscAssetsObserver()
    let mnemonic: CovFMiscMnemonic
    let coordinator: ServiceCoordinator

    init(selected: fearless.MetaAccountModel?, mnemonic: CovFMiscMnemonic) throws {
        self.mnemonic = mnemonic
        let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
        if let selected {
            let saved = XCTestExpectation(description: "selected")
            settings.save(value: selected, runningCompletionIn: .main) { _ in saved.fulfill() }
            XCTAssertEqual(XCTWaiter().wait(for: [saved], timeout: 5), .completed)
            XCTAssertEqual(settings.value?.metaId, selected.metaId)
        }
        coordinator = ServiceCoordinator(
            walletSettings: settings,
            accountInfoService: accountInfo,
            githubPhishingService: phishing,
            scamSyncService: CovFMiscSyncService(),
            polkaswapSettingsService: CovFMiscSyncService(),
            walletConnect: walletConnect,
            walletAssetsObserver: assets,
            pricesService: CovFMiscPricesServiceStub(),
            bitcoinMnemonicProvider: mnemonic,
            notificationCenter: NotificationCenter()
        )
    }
}

class CovFMiscApplicationService: ApplicationServiceProtocol {
    private(set) var setups = 0
    private(set) var throttles = 0
    func setup() { setups += 1 }
    func throttle() { throttles += 1 }
}

final class CovFMiscAccountInfoService: CovFMiscApplicationService, AccountInfoUpdatingServiceProtocol {
    private(set) var updates: [String] = []
    func update(selectedMetaAccount: fearless.MetaAccountModel) { updates.append(selectedMetaAccount.metaId) }
}

final class CovFMiscAssetsObserver: CovFMiscApplicationService, WalletAssetsObserver {
    private(set) var updates: [String] = []
    func update(wallet: fearless.MetaAccountModel) { updates.append(wallet.metaId) }
    func updateVisibility(wallet: fearless.MetaAccountModel?, chainAssets _: [ChainAsset]) async -> fearless.MetaAccountModel {
        wallet ?? AccountGenerator.generateMetaAccount()
    }
}

final class CovFMiscSyncService: ScamSyncServiceProtocol, PolkaswapSettingsSyncServiceProtocol {
    func syncUp() {}
}

final class CovFMiscPricesServiceStub: PricesServiceProtocol {
    func setup() {}
    func updatePrices() {}
}

final class CovFMiscWalletConnect: CovFMiscApplicationService, WalletConnectService {
    func set(listener _: WalletConnectServiceDelegate) {}
    func connect(uri _: String) async throws {}
    func disconnect(topic _: String) async throws {}
    func disconnectAll() async throws {}
    func getSessions() -> [Session] { [] }
    func isPending(request _: Request) async -> Bool { false }
    func legacySessionsNeedingReconnect() -> [WalletConnectLegacySession] { [] }
    func submit(proposalDecision _: WalletConnectProposalDecision) async throws {}
    func submit(signDecision _: WalletConnectSignDecision) async throws {}
}

final class CovFMiscMnemonic: UniversalWalletRootMnemonicProviding {
    private let lock = NSLock()
    private let error: Error?
    private var storedWallets: [String] = []

    init(error: Error?) { self.error = error }

    var calls: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedWallets.count
    }

    var wallets: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedWallets
    }

    func rootMnemonic(for wallet: fearless.MetaAccountModel) throws -> String? {
        lock.lock()
        storedWallets.append(wallet.metaId)
        lock.unlock()
        if let error { throw error }
        return nil
    }
}
