import Foundation
import WalletCore
import XCTest
@testable import WalletEngine

final class VaultTests: XCTestCase {
    let password = "Example-Test-Account-2026"
    let next = "Updated-Test-Password-2026"
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    var config: WalletEngineConfiguration {
        .init(storageDirectory: root, keychainService: "test.fearless.\(root.lastPathComponent)", urlSession: .shared)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
    }

    func testVaultLifecycleWalletPersistenceAndProtectedExports() async throws {
        let store = EngineStore(configuration: config)
        var states = store.stateUpdates().makeAsyncIterator()
        let initial = await states.next()
        XCTAssertEqual(initial, .uninitialized)
        do { try await store.initialize(password: "password"); XCTFail("Weak password accepted") }
        catch { XCTAssertEqual(error as? WalletError, .passwordTooWeak) }
        try await store.initialize(password: password)
        let opened = await states.next()
        XCTAssertEqual(opened, .unlocked)
        let words = Array(repeating: "abandon", count: 11) + ["about"]
        let valid = await store.validateMnemonic(words)
        XCTAssertEqual(valid, .valid)
        let source = WalletImportSource.mnemonic(
            words: words,
            options: .init(substrateDerivationPath: "//wallet///Published-Test-Path")
        )
        let preview = try await store.previewAddresses(for: source)
        let before = try await store.wallets()
        XCTAssertTrue(before.isEmpty)
        let wallet = try await store.addWallet(name: "Test", source: source)
        let dot = try XCTUnwrap(Catalog.networks.first)
        let address = try await store.address(of: wallet.id, on: dot.id)
        XCTAssertEqual(address, preview.substrate)
        do { _ = try await store.addWallet(name: "Duplicate", source: source); XCTFail("Duplicate accepted") }
        catch { XCTAssertEqual(error as? WalletError, .duplicateWallet(existing: wallet.id)) }
        for file in ["vault.json", "wallets.json"] {
            let path = root.appendingPathComponent(file)
            let attr = try FileManager.default.attributesOfItem(atPath: path.path)
            XCTAssertEqual(attr[.posixPermissions] as? Int, 0o600)
            let data = try Data(contentsOf: path)
            XCTAssertNil(data.range(of: Data("Published-Test-Path".utf8)))
            XCTAssertNil(data.range(of: Data(words.joined(separator: " ").utf8)))
        }
        try await store.renameWallet(wallet.id, to: "Renamed")
        try await store.markBackedUp(wallet.id)
        do {
            _ = try await store
                .exportMnemonic(wallet.id, approval: .password("incorrect")); XCTFail("Export bypassed approval")
        } catch { XCTAssertEqual(error as? WalletError, .wrongPassword) }
        let exported = try await store.exportMnemonic(wallet.id, approval: .password(password))
        XCTAssertEqual(exported.words, words)
        XCTAssertEqual(exported.options.substrateDerivationPath, "//wallet///Published-Test-Path")
        let backup = try await store.exportJSON(
            wallet.id,
            ecosystem: .substrate,
            approval: .password(password),
            exportPassword: next
        )
        let restored = try await store.previewAddresses(for: .json(data: backup, password: next))
        XCTAssertEqual(restored.substrate, preview.substrate)
        try await store.changePassword(current: password, new: next)
        await store.lock()
        let locked = await states.next()
        XCTAssertEqual(locked, .locked)
        try await store.verify(.password(next))
        let state = await store.state()
        XCTAssertEqual(state, .locked)
        do { _ = try await store.exportMnemonic(wallet.id, approval: .password(next)); XCTFail("Locked export") }
        catch { XCTAssertEqual(error as? WalletError, .vaultLocked) }
        let reopened = EngineStore(configuration: config)
        do { try await reopened.unlock(.password(password)); XCTFail("Old password accepted") }
        catch { XCTAssertEqual(error as? WalletError, .wrongPassword) }
        try await reopened.unlock(.password(next))
        let persisted = try await reopened.wallet(wallet.id)
        XCTAssertEqual(persisted.name, "Renamed")
        XCTAssertTrue(persisted.isBackedUp)
        try await reopened.deleteWallet(wallet.id)
        try await reopened.eraseAllData()
        let erased = await reopened.state()
        XCTAssertEqual(erased, .uninitialized)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    func testGeneratedWalletKeepsCreatedOriginWithoutPersistingPhrase() async throws {
        let store = EngineStore(configuration: config, mnemonicGenerator: { _ in
            Array(repeating: "abandon", count: 11) + ["about"]
        })
        try await store.initialize(password: password)
        let words = try await store.generateMnemonic(length: .words12)
        let created = try await store.addWallet(name: "New", source: .created(words: words, options: .standard))
        XCTAssertEqual(created.origin, .created)
        XCTAssertFalse(created.isBackedUp)
        try await store.markBackedUp(created.id)
        let marked = try await store.wallet(created.id)
        XCTAssertTrue(marked.isBackedUp)
        try await store.deleteWallet(created.id)
        let restored = try await store.addWallet(name: "Restored", source: .mnemonic(words: words, options: .standard))
        XCTAssertEqual(restored.origin, .mnemonic)
        XCTAssertTrue(restored.isBackedUp)
        XCTAssertEqual(restored.accounts, created.accounts)
    }

    func testPersistentBackoffAndCiphertextTamper() async throws {
        let instant = Date(timeIntervalSince1970: 1_800_000_000)
        let store = EngineStore(configuration: config, clock: { instant })
        try await store.initialize(password: password)
        await store.lock()
        for _ in 0 ..< 5 {
            do { try await store.unlock(.password("incorrect")); XCTFail("Wrong password accepted") }
            catch { XCTAssertEqual(error as? WalletError, .wrongPassword) }
        }
        let reopened = EngineStore(configuration: config, clock: { instant })
        do { try await reopened.unlock(.password(password)); XCTFail("Backoff bypassed") }
        catch { guard case WalletError.storage = error else { return XCTFail("Missing backoff") } }
        let files = EngineFiles(directory: root)
        var doc = try XCTUnwrap(files.read(VaultDocument.self, "vault.json"))
        XCTAssertEqual(doc.failures, 5)
        XCTAssertEqual(doc.retryAfter, instant.addingTimeInterval(1))
        doc.retryAfter = .distantPast
        doc.secrets[doc.secrets.count - 1] ^= 1
        try files.write(doc, "vault.json")
        do { try await reopened.unlock(.password(password)); XCTFail("Damaged vault unlocked") }
        catch { guard case WalletError.storage = error else { return XCTFail("Missing authentication failure") } }
        let state = await reopened.state()
        XCTAssertEqual(state, .locked)
    }

    func testMnemonicValidationAndWatchOnlyBeforeInitialization() async throws {
        let store = EngineStore(configuration: config)
        XCTAssertEqual(store.mnemonicWordList.count, 2048)
        let bad = await store.validateMnemonic(Array(repeating: "abandon", count: 12))
        let unknown = await store.validateMnemonic(["unlisted"] + Array(repeating: "abandon", count: 11))
        let empty = await store.validateMnemonic([])
        XCTAssertEqual(bad, .invalidChecksum)
        XCTAssertEqual(unknown, .unknownWords(indices: [0]))
        XCTAssertEqual(empty, .invalidLength(count: 0))
        for length in MnemonicLength.allCases {
            let words = try await store.generateMnemonic(length: length)
            XCTAssertEqual(words.count, length.rawValue)
            let result = await store.validateMnemonic(words)
            XCTAssertEqual(result, .valid)
        }
        let wallet = try await store.addWallet(
            name: "Watch",
            source: .watchOnly(substrateAddress: nil, evmAddress: "0x0000000000000000000000000000000000000001")
        )
        XCTAssertTrue(wallet.isWatchOnly)
        let state = await store.state()
        XCTAssertEqual(state, .uninitialized)
        try await store.deleteWallet(wallet.id)
    }
}
