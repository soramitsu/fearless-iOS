import CryptoKit
import Darwin
import Foundation
import LocalAuthentication
import WalletCore
import XCTest
@testable import WalletEngine

private final class BiometricFixture: BiometricKeyAccessing, @unchecked Sendable {
    private let lock = NSLock()
    private var key: SymmetricKey?
    private var failSave = false
    private var failRemove = false

    func refuseNextSave() {
        lock.withLock { failSave = true }
    }

    func refuseNextRemoval() {
        lock.withLock { failRemove = true }
    }

    let denyEnrollment: Bool
    let reading = XCTestExpectation(description: "Keychain read started")
    let resume = DispatchSemaphore(value: 0)
    init(denyEnrollment: Bool = false) {
        self.denyEnrollment = denyEnrollment
    }

    func availability() -> BiometricsAvailability {
        lock.withLock { key == nil ? .available : .enabled }
    }

    func save(_ key: SymmetricKey) throws {
        if denyEnrollment {
            throw BiometricItemError.missingEntitlement
        }
        try lock.withLock {
            if failSave {
                failSave = false
                throw WalletError.biometricsUnavailable
            }
            self.key = key
        }
    }

    func read(reason _: String, context _: LAContext) throws -> SymmetricKey {
        reading.fulfill()
        guard resume.wait(timeout: .now() + 10) == .success,
              let value = lock.withLock({ key }) else { throw WalletError.biometricsCancelled }
        return value
    }

    func remove(allowMissingEntitlement _: Bool) throws {
        try lock.withLock {
            if failRemove {
                failRemove = false
                throw WalletError.biometricsUnavailable
            }
            key = nil
        }
    }
}

final class BiometricTests: XCTestCase {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let password = "Public-Example-Password-48"
    var cfg: WalletEngineConfiguration {
        .init(storageDirectory: directory, keychainService: directory.lastPathComponent, urlSession: .shared)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func testLockInvalidatesOutstandingBiometricUnlock() async throws {
        let backend = BiometricFixture(), store = EngineStore(configuration: cfg, biometrics: backend)
        try await store.initialize(password: password)
        try await store.setBiometricsEnabled(true, password: password)
        let enrolled = await store.biometricsAvailability()
        XCTAssertEqual(enrolled, .enabled)
        await store.lock()
        let unlock = Task { try await store.unlock(.biometrics(reason: "Unlock public test fixture")) }
        await fulfillment(of: [backend.reading], timeout: 5)
        await store.lock()
        backend.resume.signal()
        do { try await unlock.value; XCTFail("Stale approval unlocked the vault") }
        catch { XCTAssertTrue(error is WalletError) }
        let state = await store.state()
        XCTAssertEqual(state, .locked)
        try await store.setBiometricsEnabled(false, password: password)
        let disabled = await store.biometricsAvailability()
        XCTAssertEqual(disabled, .available)
    }

    func testPasswordChangeRekeysSecretsAndResumesBiometricRotationAfterJournalReplay() async throws {
        let backend = BiometricFixture(), store = EngineStore(configuration: cfg, biometrics: backend)
        let next = "Next-Example-Password-48"
        let words = Array(repeating: "abandon", count: 11) + ["about"]
        try await store.initialize(password: password)
        let wallet = try await store.addWallet(name: "Fixture", source: .mnemonic(words: words, options: .standard))
        try await store.setBiometricsEnabled(true, password: password)
        let old = try await store.document()
        let active = await store.key
        let oldKey = try XCTUnwrap(active)
        backend.refuseNextSave()
        do { try await store.changePassword(current: password, new: next); XCTFail("Keychain error hidden") }
        catch { guard case let WalletError.storage(reason) = error, reason.contains("Password changed") else {
            return XCTFail("Expected separate keychain update failure")
        } }
        let pending = try await store.document()
        XCTAssertTrue(pending.biometricRekeyPending == true)
        XCTAssertFalse(pending.biometrics)
        XCTAssertFalse(old.secrets == pending.secrets)
        XCTAssertThrowsError(try AES.GCM.open(
            AES.GCM.SealedBox(combined: pending.secrets),
            using: oldKey,
            authenticating: Data("Fearless.wallets.v2".utf8)
        ))
        // Recreate a stop after journal publication and before the files have been replaced.
        let files = EngineFiles(directory: directory)
        let metadata = try XCTUnwrap(files.contents(of: "wallets.json"))
        try files.write(WalletTransaction(vault: pending, metadata: metadata, wallets: nil), "wallet-update.json")
        try files.write(old, "vault.json")
        try files.write([Wallet](), "wallets.json")
        let reopened = EngineStore(configuration: cfg, biometrics: backend)
        try await reopened.recover()
        XCTAssertEqual(try files.contents(of: "wallets.json"), metadata)
        do { try await reopened.unlock(.password(password)); XCTFail("Old password accepted after replay") }
        catch { XCTAssertEqual(error as? WalletError, .wrongPassword) }
        try await reopened.unlock(.password(next))
        let completed = try await reopened.document()
        XCTAssertNil(completed.biometricRekeyPending)
        XCTAssertTrue(completed.biometrics)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("wallet-update.json").path))
        let newKey = await reopened.key
        XCTAssertFalse(oldKey == newKey)
        await reopened.lock()
        backend.resume.signal()
        try await reopened.unlock(.biometrics(reason: "Read public fixture"))
        let recovered = try await reopened.exportMnemonic(wallet.id, approval: .password(next))
        XCTAssertTrue(recovered.words == words)
    }

    func testEraseRemovesFilesAndReportsSeparateKeychainFailure() async throws {
        let backend = BiometricFixture(), store = EngineStore(configuration: cfg, biometrics: backend)
        try await store.initialize(password: password)
        try await store.setBiometricsEnabled(true, password: password)
        backend.refuseNextRemoval()
        do { try await store.eraseAllData(); XCTFail("Keychain cleanup failure hidden") }
        catch { guard case let WalletError.storage(reason) = error, reason.contains("Wallet files erased") else {
            return XCTFail("Expected a separate keychain cleanup error")
        } }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
        let state = await store.state()
        XCTAssertEqual(state, .uninitialized)
        try await store.eraseAllData()
        XCTAssertEqual(backend.availability(), .available)
    }

    func testMissingEntitlementAndDirectoryLeaseAndEraseRecovery() async throws {
        let store = EngineStore(configuration: cfg, biometrics: BiometricFixture(denyEnrollment: true))
        try await store.initialize(password: password)
        do {
            try await store.setBiometricsEnabled(true, password: password); XCTFail("Unprotected enrollment succeeded")
        } catch { XCTAssertEqual(error as? WalletError, .biometricsUnavailable) }
        let available = await store.biometricsAvailability()
        guard case let .unavailable(reason) = available else { return XCTFail("Missing entitlement was hidden") }
        XCTAssertTrue(reason.contains("entitlement"))
        let fd = open(directory.path, O_DIRECTORY | O_RDONLY)
        XCTAssertGreaterThanOrEqual(fd, 0)
        defer { close(fd) }
        XCTAssertEqual(flock(fd, LOCK_EX | LOCK_NB), -1)
        let temp = directory.appendingPathComponent(".fearless-write-ABC123")
        try Data([1]).write(to: temp)
        try await store.eraseAllData()
        XCTAssertFalse(FileManager.default.fileExists(atPath: temp.path))
    }
}
