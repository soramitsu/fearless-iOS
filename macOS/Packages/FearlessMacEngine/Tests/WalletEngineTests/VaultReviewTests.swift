import CryptoKit
import Darwin
import Foundation
import IrohaCrypto
import WalletCore
import XCTest
@testable import WalletEngine

final class VaultReviewTests: XCTestCase {
    private let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    private let password = "Fixture-Password-42"
    private let words = Array(repeating: "abandon", count: 11) + ["about"]
    private let publicEVM = "0x0000000000000000000000000000000000000001"

    private var configuration: WalletEngineConfiguration {
        .init(storageDirectory: root, keychainService: root.lastPathComponent, urlSession: .shared)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
    }

    func testLegacyCostsRawPasswordAndAuthenticatedPathMigration() async throws {
        let files = EngineFiles(directory: root)
        let typed = "Cafe\u{0301}-Fixture-2026"
        let composed = typed.precomposedStringWithCanonicalMapping
        let options = DerivationOptions(substrateCryptoType: .ed25519, substrateDerivationPath: "//hard///fixture")
        let imported = try WalletKeys.importSource(.mnemonic(words: words, options: options))
        let legacyAccounts = imported.accounts.map { account -> WalletAccount in
            var old = account
            old.derivationPath = nil
            return old
        }
        let record = Wallet(name: "Fixture", origin: .mnemonic, accounts: legacyAccounts, isBackedUp: true)
        let secrets = try JSONEncoder().encode([record.id.description: XCTUnwrap(imported.secret)])
        for cost in [1 << 15, 1 << 16] {
            let store = EngineStore(configuration: configuration)
            let key = SymmetricKey(size: .bits256)
            var legacy = VaultDocument(salt: Data(repeating: 17, count: 32), wrappedKey: Data(), secrets: Data())
            legacy.version = 1
            legacy.cost = cost
            let rawKey = try IRScryptKeyDeriviation().deriveKey(
                from: Data(typed.utf8), salt: legacy.salt, scryptN: UInt(cost), scryptP: 1, scryptR: 8, length: 32
            )
            legacy.wrappedKey = try XCTUnwrap(AES.GCM.seal(
                key.withUnsafeBytes { Data($0) }, using: SymmetricKey(data: rawKey),
                authenticating: Data("Fearless.key.v1".utf8)
            ).combined)
            legacy.secrets = try XCTUnwrap(AES.GCM.seal(
                secrets, using: key, authenticating: Data("Fearless.wallets.v1".utf8)
            ).combined)
            try files.write(legacy, "vault.json")
            var altered = record
            altered.accounts[0].publicKey[0] ^= 1
            try files.write([altered], "wallets.json")
            do { try await store.unlock(.password(typed)); XCTFail("Migrated a mismatched signing account") }
            catch { guard case WalletError.storage = error else { return XCTFail("Expected legacy integrity error") } }
            try files.write(WalletTransaction(vault: legacy, metadata: nil, wallets: [record]), "wallet-update.json")
            try await store.unlock(.password(typed))
            let upgraded = try XCTUnwrap(files.read(VaultDocument.self, "vault.json"))
            XCTAssertEqual(upgraded.cost, 1 << 17)
            XCTAssertEqual(upgraded.version, 2)
            XCTAssertNotNil(upgraded.metadataTag)
            let restored = try await store.wallet(record.id)
            XCTAssertEqual(restored.accounts, imported.accounts)
            await store.lock()
            try await store.unlock(.password(composed))
            let backup = try await store.exportMnemonic(record.id, approval: .password(typed))
            XCTAssertTrue(backup == MnemonicBackup(words: words, options: options))
        }
    }

    func testNewPasswordsUseNFCAndNewVaultUses131072() async throws {
        let store = EngineStore(configuration: configuration)
        let typed = "New-Cafe\u{0301}-2026"
        try await store.initialize(password: typed)
        let doc = try await store.document()
        XCTAssertEqual(doc.cost, 131_072)
        XCTAssertEqual(doc.parallelism, 1)
        XCTAssertEqual(doc.blockSize, 8)
        await store.lock()
        try await store.unlock(.password(typed.precomposedStringWithCanonicalMapping))
    }

    func testCachedAddressesAndWatchOnlyMetadataAuthentication() async throws {
        let store = EngineStore(configuration: configuration), files = EngineFiles(directory: root)
        let watch = try await store.addWallet(name: "Watch", source: .watchOnly(substrateAddress: nil, evmAddress: publicEVM))
        try await store.initialize(password: password)
        let signing = try await store.addWallet(name: "Signing", source: .mnemonic(words: words, options: .standard))
        await store.lock()
        try await store.unlock(.password(password))
        let dot = try XCTUnwrap(Catalog.networks.first(where: { $0.prefix == 0 })).id
        let eth = try XCTUnwrap(Catalog.networks.first(where: { $0.evmID == 1 })).id
        let expected = try await store.address(of: signing.id, on: dot)
        let saved = try await store.document()
        let original = try XCTUnwrap(files.contents(of: "wallets.json"))
        var damaged = saved
        damaged.secrets[0] ^= 1
        try files.write(damaged, "vault.json")
        var list = try await store.wallets()
        let i = try XCTUnwrap(list.firstIndex { $0.id == watch.id })
        list[i].accounts[0].publicKey = Data(repeating: 2, count: 20)
        try files.write(list, "wallets.json")
        // Public reads must use the authenticated snapshot even if both disk files become unreadable/untrusted.
        let signingAddress = try await store.address(of: signing.id, on: dot)
        let watchAddress = try await store.address(of: watch.id, on: eth)
        XCTAssertEqual(signingAddress, expected)
        XCTAssertEqual(watchAddress, publicEVM)
        try files.write(saved, "vault.json")
        let reopened = EngineStore(configuration: configuration)
        do { try await reopened.unlock(.password(password)); XCTFail("Modified watch-only address accepted") }
        catch { guard case WalletError.storage = error else { return XCTFail("Expected metadata failure") } }
        // Semantically identical JSON still has different authenticated bytes.
        try files.write(original + Data([0x0A]), to: "wallets.json")
        do { try await reopened.unlock(.password(password)); XCTFail("Reformatted metadata accepted") }
        catch { guard case WalletError.storage = error else { return XCTFail("Expected exact-byte MAC failure") } }
        try files.write(original, to: "wallets.json")
        var downgraded = saved
        downgraded.version = 1
        downgraded.metadataTag = nil
        try files.write(downgraded, "vault.json")
        do { try await reopened.unlock(.password(password)); XCTFail("Downgrade bypassed MAC") }
        catch { guard case WalletError.storage = error else { return XCTFail("Expected vault authentication failure") } }
    }

    func testBackupRestoresNonDefaultPathsButPublicMetadataOmitsPasswords() async throws {
        let store = EngineStore(configuration: configuration)
        let options = DerivationOptions(
            substrateCryptoType: .ed25519, substrateDerivationPath: "//polkadot///fixture-sub-password",
            evmDerivationPath: "m/44'/60'/0'/0/3///fixture-evm-password"
        )
        try await store.initialize(password: password)
        let wallet = try await store.addWallet(name: "Fixture", source: .mnemonic(words: words, options: options))
        XCTAssertEqual(wallet.account(for: .substrate)?.derivationPath, "//polkadot")
        XCTAssertEqual(wallet.account(for: .evm)?.derivationPath, "m/44'/60'/0'/0/3")
        let noPath = try WalletKeys.importSource(.mnemonic(words: words, options: .init(substrateDerivationPath: "///fixture")))
        XCTAssertNil(noPath.accounts.first(where: { $0.ecosystem == .substrate })?.derivationPath)
        for name in ["wallets.json", "vault.json"] {
            let bytes = try Data(contentsOf: root.appendingPathComponent(name))
            XCTAssertNil(bytes.range(of: Data("fixture-sub-password".utf8)))
            XCTAssertNil(bytes.range(of: Data("fixture-evm-password".utf8)))
        }
        let backup = try await store.exportMnemonic(wallet.id, approval: .password(password))
        XCTAssertTrue(backup == MnemonicBackup(words: words, options: options))
        let recovered = try WalletKeys.importSource(.mnemonic(words: backup.words, options: backup.options))
        XCTAssertEqual(recovered.accounts, wallet.accounts)
    }

    func testJSONExportRejectsEmptyAndWeakPasswords() async throws {
        let store = EngineStore(configuration: configuration)
        try await store.initialize(password: password)
        let wallet = try await store.addWallet(name: "Fixture", source: .mnemonic(words: words, options: .standard))
        for weak in ["", "password123"] {
            do {
                _ = try await store.exportJSON(wallet.id, ecosystem: .substrate, approval: .password(password), exportPassword: weak)
                XCTFail("Weak export accepted")
            } catch { XCTAssertEqual(error as? WalletError, .passwordTooWeak) }
        }
    }

    func testBackoffClampsPersistedDeadlineOnlyOnce() async throws {
        let store = EngineStore(configuration: configuration), files = EngineFiles(directory: root)
        try await store.initialize(password: password)
        await store.lock()
        var doc = try await store.document()
        doc.retryAfter = .distantFuture
        try files.write(doc, "vault.json")
        let lower = Date().addingTimeInterval(4096)
        var first: Date?
        for _ in 0 ..< 2 {
            do { try await store.verify(.password(password)); XCTFail("Ignored backoff") }
            catch { guard case WalletError.storage = error else { return XCTFail("Expected backoff") } }
            let saved = try XCTUnwrap(files.read(VaultDocument.self, "vault.json")?.retryAfter)
            XCTAssertGreaterThanOrEqual(saved, lower)
            XCTAssertLessThanOrEqual(saved, Date().addingTimeInterval(4096))
            if let first {
                XCTAssertEqual(saved, first)
            }
            first = saved
        }
    }

    func testExistingDirectoryPermissionsAndFullSyncFailureBeforeRename() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
        let files = EngineFiles(directory: root)
        try files.write(1, "wallet-update.json")
        let attributes = try FileManager.default.attributesOfItem(atPath: root.path)
        XCTAssertEqual(attributes[.posixPermissions] as? Int, 0o700)
        let failing = EngineFiles(directory: root, flush: { _, command in
            XCTAssertEqual(command, F_FULLFSYNC)
            return -1
        })
        XCTAssertThrowsError(try failing.write(2, "wallet-update.json"))
        XCTAssertEqual(try files.read(Int.self, "wallet-update.json"), 1)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), ["wallet-update.json"])
    }

    func testSlotOwnershipSurvivesLateWatcherCompletion() async throws {
        let store = EngineStore(configuration: configuration)
        let first = try await store.beginTransfer("fixture")
        await store.endTransfer("fixture", owner: first)
        let second = try await store.beginTransfer("fixture")
        await store.endTransfer("fixture", owner: first)
        do { _ = try await store.beginTransfer("fixture"); XCTFail("Older watcher released newer transfer") }
        catch { guard case let WalletError.transferRejected(reason) = error, reason.contains("node acceptance") else {
            return XCTFail("Expected acceptance-in-progress error")
        } }
        await store.endTransfer("fixture", owner: second)
        _ = try await store.beginTransfer("fixture")
    }
}
