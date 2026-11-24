import IrohaCrypto
import LocalAuthentication
import RobinHood
import SoraKeystore
import SSFModels
import XCTest
@testable import fearless

// MARK: - Doubles

enum ProtectedTestFailure: Error {
    case injected
}

/// The legacy keychain: key items by tag, with an inventory and failure injection.
final class LegacyStoreDouble: KeystoreProtocol, LegacyKeychainInventory {
    private let lock = NSLock()
    private(set) var items: [String: Data] = [:]
    var failDeleteAt: Int?
    private var deletes = 0

    func addKey(_ key: Data, with identifier: String) throws {
        lock.lock(); defer { lock.unlock() }
        guard items[identifier] == nil else { throw KeystoreError.duplicatedItem }
        items[identifier] = key
    }

    func updateKey(_ key: Data, with identifier: String) throws {
        lock.lock(); defer { lock.unlock() }
        guard items[identifier] != nil else { throw KeystoreError.noKeyFound }
        items[identifier] = key
    }

    func fetchKey(for identifier: String) throws -> Data {
        lock.lock(); defer { lock.unlock() }
        guard let data = items[identifier] else { throw KeystoreError.noKeyFound }
        return data
    }

    func checkKey(for identifier: String) throws -> Bool {
        lock.lock(); defer { lock.unlock() }
        return items[identifier] != nil
    }

    func deleteKey(for identifier: String) throws {
        lock.lock(); defer { lock.unlock() }
        deletes += 1
        if deletes == failDeleteAt { throw ProtectedTestFailure.injected }
        guard items.removeValue(forKey: identifier) != nil else { throw KeystoreError.noKeyFound }
    }

    func applicationTags() throws -> [String] {
        lock.lock(); defer { lock.unlock() }
        return Array(items.keys)
    }
}

/// Protected items: a read needs a context; knobs for cancel, failures and passcode removal.
final class ProtectedBackendDouble: ProtectedSecretBackend {
    private let lock = NSLock()
    private(set) var items: [String: Data] = [:]
    var failAddAt: Int?
    var failReadAt: Int?
    var cancelReads = false
    var corruptReads = false
    var passcodeSet = true
    private(set) var adds = 0
    private(set) var reads = 0
    private(set) var readContexts: [LAContext] = []
    var onAdd: ((Int) -> Void)?

    func add(_ data: Data, for account: String) throws {
        lock.lock()
        adds += 1
        let count = adds
        defer { lock.unlock() }
        guard passcodeSet else { throw ProtectedKeychainError.passcodeNotSet }
        if count == failAddAt { throw ProtectedKeychainError.unexpected(-1) }
        guard items[account] == nil else { throw ProtectedKeychainError.duplicatedItem }
        items[account] = data
        onAdd?(count)
    }

    func read(for account: String, context: LAContext) throws -> Data {
        lock.lock(); defer { lock.unlock() }
        reads += 1
        readContexts.append(context)
        if reads == failReadAt { throw ProtectedKeychainError.unexpected(-2) }
        if cancelReads { throw ProtectedKeychainError.canceled }
        guard let data = items[account] else { throw ProtectedKeychainError.noKeyFound }
        return corruptReads ? data + Data([0]) : data
    }

    func update(_ data: Data, for account: String, context _: LAContext) throws {
        lock.lock(); defer { lock.unlock() }
        if cancelReads { throw ProtectedKeychainError.canceled }
        guard items[account] != nil else { throw ProtectedKeychainError.noKeyFound }
        items[account] = data
    }

    func exists(for account: String) throws -> Bool {
        lock.lock(); defer { lock.unlock() }
        return items[account] != nil
    }

    func delete(for account: String) throws {
        lock.lock(); defer { lock.unlock() }
        guard items.removeValue(forKey: account) != nil else { throw ProtectedKeychainError.noKeyFound }
    }

    func allAccounts() throws -> [String] {
        lock.lock(); defer { lock.unlock() }
        return items.keys.sorted()
    }

    /// iOS deletes every passcode-bound item when the passcode is removed.
    func removePasscode() {
        lock.lock(); defer { lock.unlock() }
        passcodeSet = false
        items.removeAll()
    }
}

final class JournalDouble: ProtectedWalletSecretJournaling {
    private let lock = NSLock()
    private var stored: [MetaAccountId: ProtectedWalletSecretRecord] = [:]
    var failSaveAt: Int?
    private(set) var saves = 0
    var onSave: ((ProtectedWalletSecretRecord) -> Void)?

    var records: [ProtectedWalletSecretRecord] {
        lock.lock(); defer { lock.unlock() }
        return stored.values.sorted { $0.walletId < $1.walletId }
    }

    func record(for walletId: MetaAccountId) -> ProtectedWalletSecretRecord? {
        lock.lock(); defer { lock.unlock() }
        return stored[walletId]
    }

    func save(_ record: ProtectedWalletSecretRecord) throws {
        lock.lock()
        saves += 1
        if saves == failSaveAt {
            lock.unlock()
            throw ProtectedTestFailure.injected
        }
        stored[record.walletId] = record
        lock.unlock()
        onSave?(record)
    }

    func remove(walletId: MetaAccountId) throws {
        lock.lock(); defer { lock.unlock() }
        stored[walletId] = nil
    }
}

final class DeviceOwnerDouble: DeviceOwnerAuthorizing {
    var isPasscodeSet = true
    var cancel = false
    private(set) var evaluations = 0

    func evaluate(reason _: String) throws -> LAContext {
        evaluations += 1
        if cancel { throw ProtectedKeychainError.canceled }
        return LAContext()
    }
}

/// One phone's worth of stores, re-used across a simulated restart.
final class ProtectedFixture {
    let legacy = LegacyStoreDouble()
    let protected = ProtectedBackendDouble()
    let journal = JournalDouble()
    let owner = DeviceOwnerDouble()
    let authorization = WalletSecretAuthorization(notificationCenter: NotificationCenter())
    let descriptors = BitcoinAccountDescriptorStore(userDefaults: CovHAssetListFixture.defaults())
    var enabled = true
    let wallet: MetaAccountModel
    let originals: [String: Data]

    static let phrase = "legal winner thank year wave sausage worth useful legal winner thank yellow"

    init(passwordPath: Bool = false) throws {
        authorization.setAccepting(true)
        var request = MetaAccountImportMnemonicRequest(
            mnemonic: try IRMnemonicCreator().mnemonic(fromList: Self.phrase),
            username: "protected wallet",
            substrateDerivationPath: passwordPath ? "//fearless///secret" : "",
            ethereumDerivationPath: DerivationPathConstants.defaultEthereum,
            cryptoType: .sr25519,
            defaultChainId: nil
        )
        request.universalWalletEnrollment = .generated
        let operation = MetaAccountOperationFactory(
            keystore: legacy,
            watchedAccounts: UniversalWalletWatchedAccountsStore(userDefaults: CovHAssetListFixture.defaults())
        ).newMetaAccountOperation(request: request, isBackuped: true)
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        let created = try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
        (operation as? PersistenceBoundKeychainOperation)?.commitKeychainChanges()
        wallet = created
        originals = legacy.items.filter { WalletSecretTag.belongs($0.key, to: created.metaId) }
    }

    func migrator() -> ProtectedWalletSecretMigrator {
        ProtectedWalletSecretMigrator(
            legacy: legacy,
            inventory: legacy,
            protected: protected,
            journal: journal,
            authorization: authorization,
            authorizer: owner,
            descriptorStore: descriptors,
            isEnabled: { [unowned self] in self.enabled },
            logger: nil
        )
    }

    func router() -> ProtectedWalletSecretRouter {
        ProtectedWalletSecretRouter(
            legacy: legacy,
            protected: protected,
            journal: journal,
            authorization: authorization,
            authorizer: owner
        )
    }

    /// Every original reads back unchanged through the router.
    func assertEveryOriginalReadable(file: StaticString = #filePath, line: UInt = #line) {
        let router = router()
        for (tag, data) in originals {
            XCTAssertEqual(try? router.fetchKey(for: tag), data, "Unreadable after the interruption: \(tag)", file: file, line: line)
        }
    }
}

extension ProtectedWalletSecretMigrator {
    /// The app migrates on a background queue; the system sheet never blocks the main thread.
    func migrateOffMain(_ wallet: MetaAccountModel, context: LAContext? = nil) -> Outcome {
        var outcome: Outcome = .deferred(.keychainUnavailable)
        let done = DispatchSemaphore(value: 0)
        Thread.detachNewThread {
            outcome = self.migrate(wallet, context: context)
            done.signal()
        }
        done.wait()
        return outcome
    }
}

// MARK: - Migration

final class ProtectedWalletSecretMigrationTests: XCTestCase {
    func testMigrationMovesEveryItemWithOnePromptAndDeletesOriginalsLast() throws {
        let fixture = try ProtectedFixture()
        XCTAssertGreaterThanOrEqual(fixture.originals.count, 4, "entropy, keys and paths")

        XCTAssertEqual(fixture.migrator().migrateOffMain(fixture.wallet), .committed)

        XCTAssertEqual(fixture.owner.evaluations, 1, "One system sheet for the whole wallet")
        XCTAssertEqual(fixture.protected.items, fixture.originals)
        XCTAssertTrue(fixture.originals.keys.allSatisfy { fixture.legacy.items[$0] == nil }, "Originals deleted")
        let record = try XCTUnwrap(fixture.journal.record(for: fixture.wallet.metaId))
        XCTAssertEqual(record.state, .committed)
        XCTAssertEqual(Set(record.tags), Set(fixture.originals.keys))
        XCTAssertEqual(fixture.protected.reads, fixture.originals.count, "Every copy was read back")
        XCTAssertTrue(BitcoinAccountDescriptorBackfill(store: fixture.descriptors).missingSlots(in: fixture.wallet).isEmpty,
                      "Background work needs no prompt later")
        fixture.assertEveryOriginalReadable()
        // The verification signs with every key: the wallet still signs from the protected copies.
        let identities = ProtectedWalletIdentityCheck().fingerprint(of: fixture.wallet, keystore: fixture.router())
        XCTAssertTrue(identities.contains("substrate=verified"))
        XCTAssertTrue(identities.contains("ethereum=verified"))
        XCTAssertTrue(identities.contains("slot.bitcoinMainnet=verified"))
    }

    func testPasswordWalletMovesAndKeepsItsPasswordPath() throws {
        let fixture = try ProtectedFixture(passwordPath: true)
        XCTAssertEqual(fixture.migrator().migrateOffMain(fixture.wallet), .committed)
        let path = fearless.KeystoreTagV2.substrateDerivationTagForMetaId(fixture.wallet.metaId)
        XCTAssertEqual(try fixture.router().fetchKey(for: path), Data("//fearless///secret".utf8))
        XCTAssertNil(fixture.legacy.items[path], "A path with the wallet password leaves the dumpable store")
    }

    /// Interrupt at every write, read-back, journal and delete boundary, "restart", recover and
    /// check that every secret is still readable; then the move completes.
    func testInterruptionAtEveryBoundaryNeverLosesAnItem() throws {
        let count = try ProtectedFixture().originals.count
        var scenarios: [(String, (ProtectedFixture) -> Void)] = []
        for index in 1 ... count {
            scenarios.append(("add \(index)", { $0.protected.failAddAt = index }))
            scenarios.append(("read-back \(index)", { $0.protected.failReadAt = index }))
            scenarios.append(("delete original \(index)", { $0.legacy.failDeleteAt = index }))
        }
        for save in 1 ... 4 {
            scenarios.append(("journal save \(save)", { $0.journal.failSaveAt = save }))
        }

        for (name, inject) in scenarios {
            let fixture = try ProtectedFixture()
            inject(fixture)
            _ = fixture.migrator().migrateOffMain(fixture.wallet)
            fixture.assertEveryOriginalReadable()

            // Restart: the failure is gone, a new migrator recovers first.
            fixture.protected.failAddAt = nil
            fixture.protected.failReadAt = nil
            fixture.legacy.failDeleteAt = nil
            fixture.journal.failSaveAt = nil
            let restarted = fixture.migrator()
            XCTAssertEqual(restarted.recoverInterrupted(), [], name)
            fixture.assertEveryOriginalReadable()

            let outcome = restarted.migrateOffMain(fixture.wallet)
            XCTAssertTrue(outcome == .committed || outcome == .alreadyCommitted, "\(name): \(outcome)")
            fixture.assertEveryOriginalReadable()
            XCTAssertEqual(fixture.protected.items, fixture.originals, name)
            XCTAssertTrue(fixture.originals.keys.allSatisfy { fixture.legacy.items[$0] == nil }, name)
        }
    }

    /// A process killed between steps leaves the journal state and the stores as they were at
    /// that moment. Recovery never prompts, and every secret stays readable.
    func testRecoveryFromEachKilledStateWithoutAPrompt() throws {
        typealias State = ProtectedWalletSecretRecord.State
        // (journal state, copies written, originals deleted, expected state after recovery)
        let cases: [(State, Int, Int, State)] = [
            (.staging, 0, 0, .deferred),
            (.staging, 2, 0, .deferred),
            (.written, Int.max, 0, .deferred),
            (.verified, Int.max, 0, .committed),
            (.verified, Int.max, 2, .committed),
            (.verified, Int.max, Int.max, .committed),
            (.committed, Int.max, Int.max, .committed)
        ]
        for (state, copies, deleted, expected) in cases {
            let fixture = try ProtectedFixture()
            let tags = fixture.originals.keys.sorted()
            for tag in tags.prefix(copies) {
                try fixture.protected.add(fixture.originals[tag]!, for: tag)
            }
            for tag in tags.prefix(deleted) {
                try fixture.legacy.deleteKey(for: tag)
            }
            try fixture.journal.save(ProtectedWalletSecretRecord(
                walletId: fixture.wallet.metaId, state: state, tags: tags, attempts: 1, reason: nil, updatedAt: Date()
            ))
            let label = "\(state) copies \(copies) deleted \(deleted)"
            // Before recovery, too, every read is served.
            fixture.assertEveryOriginalReadable()

            XCTAssertEqual(fixture.migrator().recoverInterrupted(), [], label)

            XCTAssertEqual(fixture.owner.evaluations, 0, "Recovery never prompts: \(label)")
            XCTAssertEqual(fixture.journal.record(for: fixture.wallet.metaId)?.state, expected, label)
            fixture.assertEveryOriginalReadable()
            if expected == .deferred {
                XCTAssertTrue(fixture.protected.items.isEmpty, label)
                XCTAssertEqual(fixture.legacy.items.filter { fixture.originals[$0.key] != nil }, fixture.originals, label)
            } else {
                XCTAssertEqual(fixture.protected.items, fixture.originals, label)
                XCTAssertTrue(tags.allSatisfy { fixture.legacy.items[$0] == nil }, label)
            }
        }
    }

    func testCancelledSheetDefersAndTouchesNothing() throws {
        let fixture = try ProtectedFixture()
        fixture.owner.cancel = true

        XCTAssertEqual(fixture.migrator().migrateOffMain(fixture.wallet), .deferred(.canceled))

        XCTAssertTrue(fixture.protected.items.isEmpty)
        XCTAssertEqual(fixture.legacy.items.filter { fixture.originals[$0.key] != nil }, fixture.originals)
        XCTAssertNil(fixture.journal.record(for: fixture.wallet.metaId), "A wallet that never started stays out of the router")
    }

    func testCancelDuringReadBackRollsBackTheCopies() throws {
        let fixture = try ProtectedFixture()
        fixture.protected.cancelReads = true

        XCTAssertEqual(fixture.migrator().migrateOffMain(fixture.wallet), .deferred(.canceled))

        XCTAssertTrue(fixture.protected.items.isEmpty)
        XCTAssertEqual(fixture.journal.record(for: fixture.wallet.metaId)?.state, .deferred)
        fixture.protected.cancelReads = false
        fixture.assertEveryOriginalReadable()
    }

    func testCopiesThatDoNotReadBackIdenticallyAreNeverCommitted() throws {
        let fixture = try ProtectedFixture()
        fixture.protected.corruptReads = true

        XCTAssertEqual(fixture.migrator().migrateOffMain(fixture.wallet), .deferred(.verificationFailed))

        XCTAssertTrue(fixture.protected.items.isEmpty)
        fixture.protected.corruptReads = false
        fixture.assertEveryOriginalReadable()
    }

    func testPreconditionsDeferWithoutAPromptOrAWrite() throws {
        let cases: [(ProtectedWalletSecretMigrator.DeferReason, (ProtectedFixture) -> MetaAccountModel)] = [
            (.disabled, { $0.enabled = false; return $0.wallet }),
            (.passcodeNotSet, { $0.owner.isPasscodeSet = false; return $0.wallet }),
            (.notBackedUp, { $0.wallet.replacingIsBackuped(false) }),
            (.unknownTags, { try? $0.legacy.addKey(Data([1]), with: $0.wallet.metaId + "-mysteryKey"); return $0.wallet }),
            (.noSecrets, { fixture in
                fixture.originals.keys.forEach { try? fixture.legacy.deleteKey(for: $0) }
                return fixture.wallet
            })
        ]
        for (reason, prepare) in cases {
            let fixture = try ProtectedFixture()
            let wallet = prepare(fixture)
            XCTAssertEqual(fixture.migrator().migrateOffMain(wallet), .deferred(reason))
            XCTAssertEqual(fixture.owner.evaluations, 0, "\(reason)")
            XCTAssertEqual(fixture.protected.adds, 0, "\(reason)")
        }
    }

    func testMissingIdentityMaterialDefers() throws {
        let fixture = try ProtectedFixture()
        // The Substrate key the wallet's identity needs is gone: nothing could verify a copy.
        try fixture.legacy.deleteKey(for: fearless.KeystoreTagV2.substrateSecretKeyTagForMetaId(fixture.wallet.metaId))

        XCTAssertEqual(fixture.migrator().migrateOffMain(fixture.wallet), .deferred(.identityUnavailable))
        XCTAssertEqual(fixture.protected.adds, 0)
    }

    func testPasscodeRemovedAfterCommitMarksTheWalletLost() throws {
        let fixture = try ProtectedFixture()
        XCTAssertEqual(fixture.migrator().migrateOffMain(fixture.wallet), .committed)

        fixture.protected.removePasscode()

        XCTAssertEqual(fixture.migrator().recoverInterrupted(), [fixture.wallet.metaId])
        XCTAssertEqual(fixture.journal.record(for: fixture.wallet.metaId)?.state, .lost)
        let tag = try XCTUnwrap(fixture.originals.keys.first)
        XCTAssertThrowsError(try fixture.router().fetchKey(for: tag)) { error in
            XCTAssertEqual(error as? KeystoreError, .noKeyFound)
        }
    }

    func testPasscodeRemovedBeforeOriginalsWentKeepsTheOriginals() throws {
        let fixture = try ProtectedFixture()
        fixture.journal.onSave = { record in
            if record.state == .verified { fixture.protected.removePasscode() }
        }

        let outcome = fixture.migrator().migrateOffMain(fixture.wallet)

        XCTAssertNotEqual(outcome, .committed)
        XCTAssertEqual(fixture.legacy.items.filter { fixture.originals[$0.key] != nil }, fixture.originals)
        XCTAssertEqual(fixture.journal.record(for: fixture.wallet.metaId)?.state, .deferred)
        fixture.assertEveryOriginalReadable()
    }

    func testVetoStopsNewMovesButMovedWalletsStayReadable() throws {
        let fixture = try ProtectedFixture()
        XCTAssertEqual(fixture.migrator().migrateOffMain(fixture.wallet), .committed)

        fixture.enabled = false

        fixture.assertEveryOriginalReadable()
        let other = try ProtectedFixture()
        other.enabled = false
        XCTAssertEqual(other.migrator().migrateOffMain(other.wallet), .deferred(.disabled))
    }

    func testBiometricUnlockContextMovesWithoutAnotherPrompt() throws {
        let fixture = try ProtectedFixture()
        let unlock = LAContext()

        XCTAssertEqual(fixture.migrator().migrateOffMain(fixture.wallet, context: unlock), .committed)

        XCTAssertEqual(fixture.owner.evaluations, 0)
        XCTAssertTrue(fixture.protected.readContexts.allSatisfy { $0 === unlock })
    }
}

// MARK: - Router

final class ProtectedWalletSecretRouterTests: XCTestCase {
    func testCancelledReadAfterCommitNeverFallsBackToTheLegacyCopy() throws {
        let fixture = try ProtectedFixture()
        fixture.legacy.failDeleteAt = 1 // stays `verified` with every original still present
        _ = fixture.migrator().migrateOffMain(fixture.wallet)
        XCTAssertEqual(fixture.journal.record(for: fixture.wallet.metaId)?.state, .verified)
        fixture.authorization.invalidate()
        fixture.protected.cancelReads = true
        let tag = try XCTUnwrap(fixture.originals.keys.first)

        let router = fixture.router()
        let reading = expectation(description: "read off the main thread")
        var caught: Error?
        var read: Data?
        Thread.detachNewThread {
            do {
                read = try router.fetchKey(for: tag)
            } catch {
                caught = error
            }
            reading.fulfill()
        }
        wait(for: [reading], timeout: 10)
        XCTAssertNil(read, "The legacy copy must not be returned")
        XCTAssertEqual(caught as? ProtectedKeychainError, .canceled)
    }

    func testProtectedItemWithoutJournalIsStillFound() throws {
        let fixture = try ProtectedFixture()
        let tag = try XCTUnwrap(fixture.originals.keys.first)
        let data = try XCTUnwrap(fixture.originals[tag])
        try fixture.legacy.deleteKey(for: tag)
        try fixture.protected.add(data, for: tag)

        XCTAssertTrue(fixture.journal.records.isEmpty)
        XCTAssertEqual(try fixture.router().fetchKey(for: tag), data)
    }

    func testRouterClaimsWalletTagsOnly() {
        let router = ProtectedWalletSecretRouter(
            legacy: LegacyStoreDouble(), protected: ProtectedBackendDouble(), journal: JournalDouble(),
            authorization: WalletSecretAuthorization(notificationCenter: NotificationCenter()),
            authorizer: DeviceOwnerDouble()
        )
        let metaId = UUID().uuidString
        XCTAssertNotNil(router.routedKeystore(for: fearless.KeystoreTagV2.entropyTagForMetaId(metaId)))
        XCTAssertNotNil(router.routedKeystore(for: fearless.KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: Data(repeating: 1, count: 20))))
        XCTAssertNil(router.routedKeystore(for: fearless.KeystoreTag.pincode.rawValue))
        XCTAssertNil(router.routedKeystore(for: fearless.KeystoreTag.pincodeAttempts.rawValue))
        XCTAssertNil(router.routedKeystore(for: "tonconnect-session-1"))
    }

    func testOneOperationShowsOneSheetForManyReads() throws {
        let fixture = try ProtectedFixture()
        XCTAssertEqual(fixture.migrator().migrateOffMain(fixture.wallet), .committed)
        fixture.authorization.invalidate()
        let before = fixture.owner.evaluations
        let router = fixture.router()

        let done = expectation(description: "operation")
        DispatchQueue.global().async {
            for tag in fixture.originals.keys {
                _ = try? router.fetchKey(for: tag)
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
        XCTAssertEqual(fixture.owner.evaluations, before + 1)
    }

    func testTagParsingRejectsOtherWalletsAndUnknownSuffixes() {
        let metaId = "A1B2C3D4-0000-0000-0000-000000000001"
        XCTAssertTrue(WalletSecretTag.belongs(metaId + "-entropy", to: metaId))
        XCTAssertTrue(WalletSecretTag.belongs(metaId + String(repeating: "ab", count: 32) + "-substrateSecretKey", to: metaId))
        XCTAssertFalse(WalletSecretTag.belongs(metaId + "1-entropy", to: metaId), "A longer id is another wallet")
        XCTAssertFalse(WalletSecretTag.belongs(metaId + "-entropyX", to: metaId))
        XCTAssertEqual(WalletSecretTag.unknownTags(in: [metaId + "-entropy", metaId + "-future"], of: metaId), [metaId + "-future"])
    }
}

// MARK: - Authorization window

final class WalletSecretAuthorizationTests: XCTestCase {
    func testAdoptedContextExpiresAndBackgroundInvalidatesIt() {
        var now = Date()
        let center = NotificationCenter()
        let authorization = WalletSecretAuthorization(now: { now }, notificationCenter: center)
        authorization.setAccepting(true)
        let context = LAContext()
        authorization.adopt(context)
        XCTAssertTrue(authorization.currentContext() === context)

        now += WalletSecretAuthorization.reuseWindow + 1
        XCTAssertNil(authorization.currentContext())

        authorization.adopt(LAContext())
        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertNil(authorization.currentContext())
    }

    func testNothingIsKeptWhileNotAccepting() {
        let authorization = WalletSecretAuthorization(notificationCenter: NotificationCenter())
        authorization.adopt(LAContext())
        XCTAssertNil(authorization.currentContext())
    }
}

// MARK: - PIN

final class PincodeVerifierTests: XCTestCase {
    func testVerifierMatchesOnlyItsPinAndHidesTheDigits() throws {
        let verifier = try PincodeVerifier.make(pin: "135790", iterations: 2000)
        XCTAssertTrue(PincodeVerifier.isVerifier(verifier))
        XCTAssertFalse(verifier.contains("135790"))
        XCTAssertTrue(PincodeVerifier.matches("135790", stored: verifier))
        XCTAssertFalse(PincodeVerifier.matches("135791", stored: verifier))
        XCTAssertFalse(PincodeVerifier.matches("", stored: verifier))
        XCTAssertNotEqual(try PincodeVerifier.make(pin: "135790", iterations: 2000), verifier, "Fresh salt each time")
    }

    func testLegacyPlainPinStillMatches() {
        XCTAssertTrue(PincodeVerifier.matches("1234", stored: "1234"))
        XCTAssertFalse(PincodeVerifier.matches("1235", stored: "1234"))
    }

    func testMalformedVerifierNeverMatches() {
        for stored in ["fearless-pin-v1$", "fearless-pin-v1$10$AAAA$AAAA", "fearless-pin-v1$999999$!!$!!", "fearless-pin-v1$1$a$b$c"] {
            XCTAssertFalse(PincodeVerifier.matches("1234", stored: stored), stored)
        }
    }

    func testUpgradeReplacesThePlainPinInPlace() {
        let store = PinStoreDouble(value: "246810")
        let done = expectation(description: "upgraded")
        PincodeVerifierUpgrade.upgrade(pin: "246810", secretManager: store) { upgraded in
            XCTAssertTrue(upgraded)
            done.fulfill()
        }
        wait(for: [done], timeout: 30)
        XCTAssertTrue(PincodeVerifier.isVerifier(store.value ?? ""))
        XCTAssertTrue(PincodeVerifier.matches("246810", stored: store.value ?? ""))
        XCTAssertFalse(store.everMissing, "The PIN item never went missing")
    }

    func testUpgradeThatCannotBeReadBackRestoresThePlainPin() {
        let store = PinStoreDouble(value: "246810")
        store.corruptNextLoad = true
        let done = expectation(description: "restored")
        PincodeVerifierUpgrade.upgrade(pin: "246810", secretManager: store) { upgraded in
            XCTAssertFalse(upgraded)
            done.fulfill()
        }
        wait(for: [done], timeout: 30)
        XCTAssertEqual(store.value, "246810")
    }
}

/// The unlock screen's interactor with a verifier, a plain PIN and the in-place upgrade.
final class PincodeVerifierUnlockTests: XCTestCase {
    private final class Output: LocalAuthInteractorOutputProtocol {
        var completed = 0
        var wrong = 0
        var onEvent: (() -> Void)?
        func didEnterWrongPincode() { wrong += 1; onEvent?() }
        func didCompleteAuth() { completed += 1; onEvent?() }
        func didChangeState(to _: LocalAuthInteractor.LocalAuthState) {}
        func didUnexpectedFail() { XCTFail("unexpected") }
    }

    private final class NoBiometry: BiometryAuthProtocol {
        var availableBiometryType: AvailableBiometryType { .none }
        func authenticate(localizedReason _: String, completionQueue _: DispatchQueue, completionBlock _: @escaping (Bool) -> Void) {}
    }

    private final class Enrollment: BiometryEnrollmentGuarding {
        func isCurrentEnrollmentTrusted() -> Bool { false }
        func trustCurrentEnrollment() {}
    }

    private func interactor(_ store: PinStoreDouble, upgrades: Bool) -> LocalAuthInteractor {
        LocalAuthInteractor(
            secretManager: store,
            settingsManager: InMemorySettingsManager(),
            biometryAuth: NoBiometry(),
            locale: Locale(identifier: "en"),
            attemptLimiter: PincodeAttemptLimiter(keystore: InMemoryKeychain()),
            enrollmentGuard: Enrollment(),
            authorizedUnlock: WalletAuthorizedUnlock(notificationCenter: NotificationCenter()),
            upgradesPincode: { upgrades }
        )
    }

    private func enter(_ pin: String, into interactor: LocalAuthInteractor, output: Output) {
        let answered = expectation(description: "answered")
        output.onEvent = { answered.fulfill() }
        interactor.startAuth(with: output)
        interactor.process(pin: pin)
        wait(for: [answered], timeout: 30)
        output.onEvent = nil
    }

    func testVerifierUnlocksWithTheRightPinOnly() throws {
        let store = PinStoreDouble(value: try PincodeVerifier.make(pin: "112233", iterations: 5000))
        let output = Output()
        let unlock = interactor(store, upgrades: false)

        enter("445566", into: unlock, output: output)
        XCTAssertEqual(output.wrong, 1)
        XCTAssertEqual(output.completed, 0)

        enter("112233", into: unlock, output: output)
        XCTAssertEqual(output.completed, 1)
    }

    func testPlainPinUnlocksAndIsReplacedByAVerifierOnlyWhenTheFlagIsOn() throws {
        for upgrades in [false, true] {
            let store = PinStoreDouble(value: "778899")
            let output = Output()
            enter("778899", into: interactor(store, upgrades: upgrades), output: output)
            XCTAssertEqual(output.completed, 1)
            if upgrades {
                let deadline = Date().addingTimeInterval(30)
                while !PincodeVerifier.isVerifier(store.value ?? ""), Date() < deadline {
                    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
                }
                XCTAssertTrue(PincodeVerifier.isVerifier(store.value ?? ""))
                XCTAssertTrue(PincodeVerifier.matches("778899", stored: store.value ?? ""))
            } else {
                RunLoop.main.run(until: Date().addingTimeInterval(0.2))
                XCTAssertEqual(store.value, "778899", "Flag off: the stored PIN is left as it was")
            }
        }
    }
}

final class PinStoreDouble: SecretStoreManagerProtocol {
    private let lock = NSLock()
    private(set) var value: String?
    private(set) var everMissing = false
    var corruptNextLoad = false

    init(value: String?) {
        self.value = value
    }

    func loadSecret(for _: String, completionQueue: DispatchQueue, completionBlock: @escaping (SecretDataRepresentable?) -> Void) {
        lock.lock()
        var result = value
        if corruptNextLoad {
            corruptNextLoad = false
            result = "fearless-pin-v1$broken"
        }
        lock.unlock()
        completionQueue.async { completionBlock(result) }
    }

    func saveSecret(_ secret: SecretDataRepresentable, for _: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
        lock.lock()
        value = secret.toUTF8String()
        lock.unlock()
        completionQueue.async { completionBlock(true) }
    }

    func removeSecret(for _: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
        lock.lock()
        value = nil
        everMissing = true
        lock.unlock()
        completionQueue.async { completionBlock(true) }
    }

    func checkSecret(for _: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
        let exists = checkSecret(for: "")
        completionQueue.async { completionBlock(exists) }
    }

    func checkSecret(for _: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return value != nil
    }
}

// MARK: - Real keychain (simulator)

final class ProtectedKeychainHostedTests: XCTestCase {
    override func tearDown() {
        Keychain.itemRouter = nil
        super.tearDown()
    }

    /// The simulator has no passcode: a passcode-bound item cannot be created there, and the
    /// migrator defers instead of touching anything.
    func testWithoutPasscodeNothingMovesOnTheRealKeychain() throws {
        let owner = SystemDeviceOwnerAuthorizer()
        let protected = ProtectedKeychain(service: "jp.co.soramitsu.fearless.tests.\(UUID().uuidString)")
        let account = "probe-\(UUID().uuidString)"
        let passcodeSet = owner.isPasscodeSet
        do {
            try protected.add(Data([1, 2, 3]), for: account)
            // Created: it is found without a prompt and deleted without one.
            XCTAssertTrue(try protected.exists(for: account))
            try protected.delete(for: account)
            XCTAssertFalse(try protected.exists(for: account))
        } catch {
            // No passcode on this device: the item cannot exist, and nothing was written.
            XCTAssertFalse(passcodeSet, "Creating failed although a passcode is set: \(error)")
            XCTAssertFalse(try protected.exists(for: account))
        }
        let migrator = ProtectedWalletSecretMigrator(
            protected: protected,
            journal: JournalDouble(),
            authorizer: owner,
            isEnabled: { true },
            logger: nil
        )
        if !passcodeSet {
            XCTAssertEqual(
                migrator.migrateOffMain(AccountGenerator.generateMetaAccount().replacingIsBackuped(true)),
                .deferred(.passcodeNotSet)
            )
        }
        XCTAssertEqual(try protected.allAccounts().filter { $0 == account }, [])
    }

    /// With the router installed, `Keychain()` sends wallet tags through it and keeps the PIN
    /// where it always was.
    func testKeychainRoutesWalletTagsOnly() throws {
        let fixture = try ProtectedFixture()
        Keychain.itemRouter = fixture.router()
        let tag = try XCTUnwrap(fixture.originals.keys.first)

        XCTAssertEqual(try Keychain().fetchKey(for: tag), fixture.originals[tag], "Served by the router's stores")
        XCTAssertFalse(try Keychain(routed: false).checkKey(for: tag), "Never written to the real keychain")

        let pin = "test-pin-\(UUID().uuidString)"
        XCTAssertNil(fixture.router().routedKeystore(for: pin))
        try? Keychain().deleteKey(for: pin)
    }

    func testRealJournalRoundTrip() throws {
        let journal = try KeychainProtectedWalletSecretJournal(service: "jp.co.soramitsu.fearless.tests.journal.\(UUID().uuidString)")
        let record = ProtectedWalletSecretRecord(
            walletId: UUID().uuidString, state: .verified, tags: ["a-entropy"], attempts: 1, reason: nil, updatedAt: Date()
        )
        try journal.save(record)
        var updated = record
        updated.state = .committed
        try journal.save(updated)
        XCTAssertEqual(journal.record(for: record.walletId)?.state, .committed)
        try journal.remove(walletId: record.walletId)
        XCTAssertNil(journal.record(for: record.walletId))
    }
}
