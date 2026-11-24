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

    func testAccountChangeOutsideAnUnlockReadsNoSecret() throws {
        let wallet = AccountGenerator.generateMetaAccount()
        let fixture = try CovFMiscCoordinatorFixture(selected: wallet, mnemonic: CovFMiscMnemonic(error: nil), unlocked: false)
        fixture.coordinator.updateOnAccountChange()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(fixture.accountInfo.updates, [wallet.metaId])
        XCTAssertEqual(fixture.mnemonic.calls, 0, "Provisioning waits for the next unlock")

        fixture.unlock.recordUnlock()
        fixture.coordinator.updateOnAccountChange()
        try covFMiscEventually { fixture.mnemonic.calls == 1 }
    }

    func testProvisionedWalletReadsNoSecretEvenRightAfterUnlock() throws {
        let base = AccountGenerator.generateMetaAccount()
        let store = BitcoinAccountDescriptorStore(userDefaults: CovHAssetListFixture.defaults())
        let wallet = try UniversalWalletAccountProvisioning.addingMissingAppOwnedAccounts(
            to: base,
            mnemonic: BitcoinTestWallet.mnemonic,
            descriptorStore: store
        )
        XCTAssertTrue(UniversalWalletAccountProvisioning.missingSlots(in: wallet).isEmpty)
        let fixture = try CovFMiscCoordinatorFixture(
            selected: wallet,
            mnemonic: CovFMiscMnemonic(error: nil),
            descriptorStore: store
        )
        fixture.coordinator.updateOnAccountChange()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(fixture.mnemonic.calls, 0, "Nothing is missing, so nothing is read")
        XCTAssertEqual(fixture.slotSecrets.calls, 0, "Its Bitcoin descriptors were saved when the accounts were added")
    }

    func testMissingBitcoinDescriptorIsMadeRightAfterUnlockOnly() throws {
        let base = AccountGenerator.generateMetaAccount()
        let wallet = try UniversalWalletAccountProvisioning.addingMissingAppOwnedAccounts(
            to: base,
            mnemonic: BitcoinTestWallet.mnemonic,
            descriptorStore: nil
        )
        let locked = try CovFMiscCoordinatorFixture(selected: wallet, mnemonic: CovFMiscMnemonic(error: nil), unlocked: false)
        locked.coordinator.updateOnAccountChange()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(locked.slotSecrets.calls, 0)

        let unlocked = try CovFMiscCoordinatorFixture(selected: wallet, mnemonic: CovFMiscMnemonic(error: nil))
        unlocked.coordinator.updateOnAccountChange()
        try covFMiscEventually { unlocked.slotSecrets.calls == 2 }
        XCTAssertEqual(unlocked.mnemonic.calls, 0, "No network was missing")
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
    let unlock = WalletAuthorizedUnlock(notificationCenter: NotificationCenter())
    let slotSecrets = CovFMiscNoSlotSecret()

    /// `unlocked`: the user has just unlocked the app, the only time provisioning reads a secret.
    init(
        selected: fearless.MetaAccountModel?,
        mnemonic: CovFMiscMnemonic,
        unlocked: Bool = true,
        descriptorStore: BitcoinAccountDescriptorStore = BitcoinAccountDescriptorStore(userDefaults: CovHAssetListFixture.defaults())
    ) throws {
        self.mnemonic = mnemonic
        if unlocked {
            unlock.recordUnlock()
        }
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
            descriptorBackfill: BitcoinAccountDescriptorBackfill(
                secretProvider: slotSecrets,
                store: descriptorStore,
                logger: nil
            ),
            authorizedUnlock: unlock,
            allWallets: { [] },
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

/// Descriptor backfill that never finds a secret (the wallets here have no Bitcoin account).
final class CovFMiscNoSlotSecret: UniversalWalletSlotSecretProviding {
    private let lock = NSLock()
    private var count = 0

    var calls: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func secret(for _: fearless.MetaAccountModel, slot _: UniversalWalletSlot) throws -> UniversalWalletSecret? {
        lock.lock()
        count += 1
        lock.unlock()
        return nil
    }
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
