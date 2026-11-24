import BigInt
import IrohaCrypto
import SoraKeystore
import SSFModels
import SSFStorageQueryKit
import SSFUtils
import XCTest
@testable import fearless

/// A keystore that records every secret read. MoldyRoost step 1: refresh, foreground events and
/// address-only connections must read none, so a keychain that asks for the device owner never
/// prompts in the background.
final class SecretStoreSpy: KeystoreProtocol {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]
    private var readTags: [String] = []

    var reads: [String] {
        lock.lock()
        defer { lock.unlock() }
        return readTags
    }

    func resetReads() {
        lock.lock()
        readTags.removeAll()
        lock.unlock()
    }

    func addKey(_ key: Data, with identifier: String) throws {
        lock.lock()
        defer { lock.unlock() }
        guard storage[identifier] == nil else { throw KeystoreError.duplicatedItem }
        storage[identifier] = key
    }

    func updateKey(_ key: Data, with identifier: String) throws {
        lock.lock()
        defer { lock.unlock() }
        guard storage[identifier] != nil else { throw KeystoreError.noKeyFound }
        storage[identifier] = key
    }

    func fetchKey(for identifier: String) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        readTags.append(identifier)
        guard let value = storage[identifier] else { throw KeystoreError.noKeyFound }
        return value
    }

    func checkKey(for identifier: String) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage[identifier] != nil
    }

    func deleteKey(for identifier: String) throws {
        lock.lock()
        defer { lock.unlock() }
        guard storage.removeValue(forKey: identifier) != nil else { throw KeystoreError.noKeyFound }
    }
}

final class BitcoinAccountDescriptorTests: XCTestCase {
    private static let mnemonic = BitcoinTestWallet.mnemonic

    /// BIP84's published vectors for the "abandon ... about" phrase.
    func testDescriptorMatchesBip84ReferenceAddresses() throws {
        let descriptor = try BitcoinKeyDerivation.deriveAccountDescriptor(mnemonic: Self.mnemonic, network: .mainnet)

        XCTAssertEqual(try descriptor.address(change: 0, index: 0), "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu")
        XCTAssertEqual(try descriptor.address(change: 0, index: 1), "bc1qnjg0jd8228aq7egyzacy8cys3knf9xvrerkf9g")
        XCTAssertEqual(try descriptor.address(change: 1, index: 0), "bc1q8c6fshw2dlwun7ekn9qwf37cu2rn755upcp6el")
    }

    /// Every address refresh derives from the descriptor equals the one the phrase derives:
    /// mainnet and testnet, receive and change, with and without a wallet password.
    func testDescriptorAddressesEqualPhraseAddresses() throws {
        for network in [BitcoinKeyDerivation.Network.mainnet, .testnet] {
            for passphrase in ["", "correct horse ✓ battery"] {
                let descriptor = try BitcoinKeyDerivation.deriveAccountDescriptor(
                    mnemonic: Self.mnemonic,
                    passphrase: passphrase,
                    network: network
                )
                let account = try BitcoinKeyDerivation.deriveAccount(
                    mnemonic: Self.mnemonic,
                    passphrase: passphrase,
                    network: network
                )
                XCTAssertEqual(try descriptor.firstReceivePublicKey(), account.publicKey)
                for change: UInt32 in [0, 1] {
                    for index: UInt32 in [0, 1, 2, 19, 20, 21, 99, 999] {
                        let path = try BitcoinKeyDerivation.getReceivePath(network: network, index: index, change: change)
                        let expected = try BitcoinKeyDerivation.deriveKey(
                            mnemonic: Self.mnemonic,
                            passphrase: passphrase,
                            derivationPath: path,
                            network: network
                        )
                        XCTAssertEqual(try descriptor.publicKey(change: change, index: index), expected.publicKey, path)
                        XCTAssertEqual(try descriptor.address(change: change, index: index), expected.address, path)
                    }
                }
            }
        }
    }

    func testDescriptorRefusesHardenedAndOutOfRangeChildren() throws {
        let descriptor = try BitcoinKeyDerivation.deriveAccountDescriptor(mnemonic: Self.mnemonic)
        XCTAssertThrowsError(try descriptor.address(change: 2, index: 0))
        XCTAssertThrowsError(try descriptor.address(change: 0, index: 0x8000_0000))
        XCTAssertThrowsError(try BitcoinKeyDerivation.AccountDescriptor(
            network: .mainnet,
            publicKey: Data([0x05] + [UInt8](repeating: 0x01, count: 32)),
            chainCode: descriptor.chainCode
        ), "Bytes that are not a curve point are refused")
    }

    func testStoreReturnsOnlyADescriptorThatDerivesTheStoredAccount() throws {
        let defaults = CovHAssetListFixture.defaults()
        let store = BitcoinAccountDescriptorStore(userDefaults: defaults)
        let wallet = try BitcoinTestWallet.wallet()
        let own = try BitcoinKeyDerivation.deriveAccountDescriptor(mnemonic: Self.mnemonic)
        let foreign = try BitcoinKeyDerivation.deriveAccountDescriptor(
            mnemonic: "legal winner thank year wave sausage worth useful legal winner thank yellow"
        )

        try store.save(foreign, walletId: wallet.metaId)
        XCTAssertNil(store.descriptor(for: wallet, chain: BitcoinTestWallet.chain), "Another phrase's descriptor is ignored")

        try store.save(own, walletId: wallet.metaId)
        XCTAssertEqual(store.descriptor(for: wallet, chain: BitcoinTestWallet.chain), own)
        XCTAssertEqual(
            BitcoinAccountDescriptorStore(userDefaults: defaults).descriptor(for: wallet, chain: BitcoinTestWallet.chain),
            own,
            "A descriptor survives a relaunch"
        )

        store.forget(walletId: wallet.metaId)
        XCTAssertNil(store.descriptor(for: wallet, chain: BitcoinTestWallet.chain))
    }

    func testAddingAppOwnedAccountsSavesTheirBitcoinDescriptors() throws {
        let store = BitcoinAccountDescriptorStore(userDefaults: CovHAssetListFixture.defaults())
        for passphrase in ["", "pass"] {
            let wallet = try UniversalWalletAccountProvisioning.addingMissingAppOwnedAccounts(
                to: AccountGenerator.generateMetaAccount(),
                mnemonic: Self.mnemonic,
                passphrase: passphrase,
                enrollment: .generated,
                descriptorStore: store
            )
            for slot in [UniversalWalletSlot.bitcoinMainnet, .bitcoinTestnet] {
                let account = try XCTUnwrap(slot.storedAccount(in: wallet))
                let network = try XCTUnwrap(slot.bitcoinNetwork)
                let descriptor = try XCTUnwrap(store.descriptor(
                    walletId: wallet.metaId,
                    network: network,
                    accountPublicKey: account.publicKey
                ))
                XCTAssertEqual(descriptor, try BitcoinKeyDerivation.deriveAccountDescriptor(
                    mnemonic: Self.mnemonic,
                    passphrase: passphrase,
                    network: network
                ))
            }
        }
    }
}

final class PassiveSecretReadTests: XCTestCase {
    private var ledger: BitcoinTestLedger!
    private var spy: SecretStoreSpy!
    private var store: BitcoinAccountDescriptorStore!
    private var wallet: MetaAccountModel!

    override func setUpWithError() throws {
        try super.setUpWithError()
        ledger = BitcoinTestLedger()
        spy = SecretStoreSpy()
        store = BitcoinAccountDescriptorStore(userDefaults: CovHAssetListFixture.defaults())
        wallet = try BitcoinTestWallet.wallet()
        let entropy = try IRMnemonicCreator().mnemonic(fromList: BitcoinTestWallet.mnemonic).entropy()
        try spy.addKey(entropy, with: fearless.KeystoreTagV2.entropyTagForMetaId(wallet.metaId))
    }

    /// The acceptance check: after the one read at an authorized unlock, background refresh
    /// reads no secret and still covers every address the phrase would.
    func testBackgroundRefreshReadsNoSecret() async throws {
        let funded: [(change: UInt32, index: UInt32, sats: Int64)] = [(0, 0, 10_000), (0, 5, 20_000), (1, 2, 30_000)]
        for coin in funded {
            let path = try BitcoinKeyDerivation.getReceivePath(index: coin.index, change: coin.change)
            let address = try BitcoinKeyDerivation.deriveKey(mnemonic: BitcoinTestWallet.mnemonic, derivationPath: path).address
            ledger.fund(address, sats: coin.sats)
        }

        // The authorized moment: the one read.
        let provider = KeychainUniversalWalletMnemonicProvider(keystore: spy)
        let backfill = BitcoinAccountDescriptorBackfill(secretProvider: provider, store: store, logger: nil)
        XCTAssertEqual(backfill.missingSlots(in: wallet), [.bitcoinMainnet])
        XCTAssertEqual(backfill.backfill(wallet), 1)
        XCTAssertFalse(spy.reads.isEmpty)
        spy.resetReads()

        // Background: refreshes, the public checks, the watched-address check of a wallet that
        // watches nothing.
        let service = AccountInfoRemoteServiceDefault(
            bitcoinBalanceSync: BitcoinBalanceSync(discovery: BitcoinReceiveDiscovery(client: ledger)),
            bitcoinDescriptorProvider: store,
            storagePerformer: PassiveSecretReadEmptyStorage()
        )
        let chainAsset = ChainAsset(chain: BitcoinTestWallet.chain, asset: BitcoinTestWallet.asset)
        for _ in 0 ..< 2 {
            await BitcoinWalletBalanceCache.shared.invalidate(walletId: wallet.metaId)
            let infos = try await service.fetchAccountInfos(for: BitcoinTestWallet.chain, wallet: wallet)
            let info = try XCTUnwrap(infos[chainAsset.chainAssetId] ?? nil)
            XCTAssertEqual(info.data.total, BigUInt(60_000), "Receive and change addresses past index 0 are counted")
        }
        XCTAssertTrue(backfill.missingSlots(in: wallet).isEmpty)
        let checker = UniversalWalletWatchedAccountsChecker(
            mnemonicProvider: provider,
            watchedAccounts: UniversalWalletWatchedAccountsStore(userDefaults: CovHAssetListFixture.defaults())
        )
        let result = await checker.check(wallet)
        XCTAssertEqual(result.wallet, wallet)

        XCTAssertEqual(spy.reads, [], "Background refresh read a wallet secret")

        // The descriptor scan is the phrase scan.
        let phraseScan = try await BitcoinBalanceSync(discovery: BitcoinReceiveDiscovery(client: ledger))
            .balance(mnemonic: BitcoinTestWallet.mnemonic)
        let descriptorScan = try await BitcoinBalanceSync(discovery: BitcoinReceiveDiscovery(client: ledger))
            .balance(descriptor: try XCTUnwrap(store.descriptor(for: wallet, chain: BitcoinTestWallet.chain)))
        XCTAssertEqual(descriptorScan, phraseScan)
    }

    /// Before the first authorized unlock after the update, refresh reads the stored address
    /// alone and says so, instead of reading the phrase.
    func testRefreshWithoutDescriptorReadsTheStoredAddressOnly() async throws {
        ledger.fund(BitcoinTestWallet.address, sats: 10_000)
        let changePath = try BitcoinKeyDerivation.getReceivePath(index: 0, change: 1)
        ledger.fund(try BitcoinKeyDerivation.deriveKey(mnemonic: BitcoinTestWallet.mnemonic, derivationPath: changePath).address, sats: 5000)
        let service = AccountInfoRemoteServiceDefault(
            bitcoinBalanceSync: BitcoinBalanceSync(discovery: BitcoinReceiveDiscovery(client: ledger)),
            bitcoinDescriptorProvider: store,
            storagePerformer: PassiveSecretReadEmptyStorage()
        )
        await BitcoinWalletBalanceCache.shared.invalidate(walletId: wallet.metaId)

        let infos = try await service.fetchAccountInfos(for: BitcoinTestWallet.chain, wallet: wallet)

        let chainAsset = ChainAsset(chain: BitcoinTestWallet.chain, asset: BitcoinTestWallet.asset)
        XCTAssertEqual(try XCTUnwrap(infos[chainAsset.chainAssetId] ?? nil).data.total, BigUInt(10_000))
        XCTAssertEqual(spy.reads, [])
    }

    /// Right after the update, before the first unlock makes the descriptor, refresh keeps the
    /// total an earlier full scan saved instead of replacing it with one address.
    func testPendingDescriptorKeepsTheLastCompleteTotal() async throws {
        let chainAsset = ChainAsset(chain: BitcoinTestWallet.chain, asset: BitcoinTestWallet.asset)
        let defaults = UserDefaults.standard
        RemoteLastKnownBalanceStore.save(
            [chainAsset.chainAssetId: AccountInfo(ethBalance: BigUInt(70_000))],
            chain: BitcoinTestWallet.chain,
            walletId: wallet.metaId,
            userDefaults: defaults
        )
        ledger.fund(BitcoinTestWallet.address, sats: 10_000)
        let service = AccountInfoRemoteServiceDefault(
            bitcoinBalanceSync: BitcoinBalanceSync(discovery: BitcoinReceiveDiscovery(client: ledger)),
            bitcoinDescriptorProvider: store,
            storagePerformer: PassiveSecretReadEmptyStorage()
        )
        await BitcoinWalletBalanceCache.shared.invalidate(walletId: wallet.metaId)

        let pending = try await service.fetchAccountInfos(for: BitcoinTestWallet.chain, wallet: wallet)
        XCTAssertEqual(try XCTUnwrap(pending[chainAsset.chainAssetId] ?? nil).data.total, BigUInt(70_000))
        XCTAssertTrue(ledger.utxoRequests.isEmpty, "Nothing is scanned while the descriptor is pending")

        // The backfill finds no secret for the account: refresh stops waiting and reads the address.
        let account = try XCTUnwrap(UniversalWalletSlot.bitcoinMainnet.storedAccount(in: wallet))
        store.markUnavailable(walletId: wallet.metaId, network: .mainnet, accountPublicKey: account.publicKey)
        let limited = try await service.fetchAccountInfos(for: BitcoinTestWallet.chain, wallet: wallet)
        XCTAssertEqual(try XCTUnwrap(limited[chainAsset.chainAssetId] ?? nil).data.total, BigUInt(10_000))
        XCTAssertEqual(spy.reads, [])
    }

    /// Two accounts of one wallet (a password switch) never share a cached scan.
    func testCachedScanIsBoundToTheAccount() async throws {
        let cache = BitcoinWalletBalanceCache()
        func key(_ account: String) -> BitcoinWalletBalanceCache.Key {
            BitcoinWalletBalanceCache.Key(
                walletId: "wallet", network: .mainnet, baseURL: nil, gapLimit: 20,
                maxLookahead: BitcoinReceiveDiscovery.defaultMaxLookahead, account: account
            )
        }
        func result(_ sats: Int64) -> BitcoinBalanceSyncResult {
            BitcoinBalanceSyncResult(
                confirmedSats: sats, mempoolSats: 0, totalSats: sats, usedAddresses: [],
                discovery: BitcoinReceiveDiscoveryResult(
                    addresses: [], gapLimit: 20, lastUsedIndex: nil, nextReceiveAddress: "",
                    nextReceiveIndex: 0, usedAddresses: []
                )
            )
        }
        _ = try await cache.value(for: key("bc1qold")) { result(1) }
        let other = try await cache.value(for: key("BC1QNEW")) { result(2) }
        XCTAssertEqual(other.totalSats, 2)
        XCTAssertEqual(key("BC1QNEW"), key("bc1qnew"), "Addresses compare without case")
    }

    /// A transfer the user confirmed reads the phrase anyway: it leaves the descriptor behind,
    /// so the next fee quote reads nothing.
    func testConfirmedTransferLeavesADescriptorAndLaterQuotesReadNoSecret() async throws {
        ledger.fund(BitcoinTestWallet.address, sats: 1_000_000)
        let mnemonic = BitcoinTestMnemonicProvider()
        let service = BitcoinTransferService(
            wallet: wallet,
            chain: BitcoinTestWallet.chain,
            client: ledger,
            mnemonicProvider: mnemonic,
            descriptorStore: store,
            sendGate: UniversalSendGate(policy: .production, remoteConfig: { .defaultConfig }),
            pendingStore: BitcoinPendingBroadcastStore(userDefaults: CovHAssetListFixture.defaults(), logger: nil),
            statusPolling: .once
        )
        let transfer = BitcoinTestWallet.transfer(sats: 100_000)

        _ = try await service.estimateFee(for: transfer)
        XCTAssertEqual(mnemonic.callCount, 1, "Without a descriptor the first quote reads the phrase")
        XCTAssertNotNil(store.descriptor(for: wallet, chain: BitcoinTestWallet.chain))

        _ = try await service.estimateFee(for: transfer)
        XCTAssertEqual(mnemonic.callCount, 1, "Later quotes read the descriptor only")
    }
}

private final class PassiveSecretReadEmptyStorage: SSFStorageQueryKit.StorageRequestPerformer {
    func performSingle<T: Decodable>(
        _: SSFStorageQueryKit.StorageRequest,
        chain _: ChainModel
    ) async throws -> T? { nil }

    func performSingle<T: Decodable>(
        _: SSFStorageQueryKit.StorageRequest,
        withCacheOptions _: SSFStorageQueryKit.CachedStorageRequestTrigger,
        chain _: ChainModel
    ) async -> AsyncThrowingStream<SSFStorageQueryKit.CachedStorageResponse<T>, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func performMultiple<K: Decodable & Hashable, T: Decodable>(
        _: SSFStorageQueryKit.MultipleRequest,
        chain _: ChainModel
    ) async throws -> [K: T]? { nil }

    func performMultiple<K: Decodable & ScaleCodable & Hashable, T: Decodable>(
        _: SSFStorageQueryKit.MultipleRequest,
        withCacheOptions _: SSFStorageQueryKit.CachedStorageRequestTrigger,
        chain _: ChainModel
    ) async -> AsyncThrowingStream<SSFStorageQueryKit.CachedStorageResponse<[K: T]>, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func performPrefix<K: Decodable & ScaleCodable & Hashable, T: Decodable>(
        _: SSFStorageQueryKit.PrefixRequest,
        withCacheOptions _: SSFStorageQueryKit.CachedStorageRequestTrigger,
        chain _: ChainModel
    ) async -> AsyncThrowingStream<SSFStorageQueryKit.CachedStorageResponse<[K: T]>, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func performPrefix<K: Decodable & Hashable, T: Decodable>(
        _: SSFStorageQueryKit.PrefixRequest,
        chain _: ChainModel
    ) async throws -> [K: T]? { nil }

    func perform(
        _: [any MixStorageRequest],
        chain _: ChainModel
    ) async throws -> [MixStorageResponse] { [] }
}
