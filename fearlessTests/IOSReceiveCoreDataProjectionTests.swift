import CoreData
import CryptoKit
@testable import fearless
import IrohaCrypto
import RobinHood
import SSFModels
import SSFUtils
import XCTest

final class IOSReceiveCoreDataProjectionTests: XCTestCase {
    fileprivate typealias Codec = IOSPortableWalletSemanticMaterial
    fileprivate typealias Projection = IOSReceiveCoreDataProjection
    fileprivate typealias Journal = IOSPortableWalletReceiveJournalRecord
    private let genesis = String(repeating: "ab", count: 32)
    private let defaultCurrency = Currency.defaultCurrency()

    func testCompletePublicCohortPersistsAndRefetchesThroughReleasedCoreDataMapper() throws {
        let substrate = try substrateSlot()
        let evm = try evmSlot()
        var chain = try substrateSlot(role: Codec.Role.chainAccount, key: genesis)
        chain.fields += [.init(id: 9, value: []), .init(id: 10, value: [1])]
        chain.fields.sort { $0.id < $1.id }
        let favorite = Codec.Slot(role: Codec.Role.favoriteChain, key: genesis, fields: [.init(id: 10, value: [1])])
        let metadata = try displayMetadata()
        let snapshot = try Codec.Snapshot(selectedIndex: 1, wallets: [
            wallet(1, slots: [substrate, evm, chain, favorite], metadata: metadata),
            wallet(2, slots: [evm]),
            wallet(3, slots: [tonSlot()]),
            wallet(4, slots: [evm, tonSlot()])
        ])
        let projection = try project(snapshot, existingOrders: [2, 41])
        XCTAssertEqual(projection.records.map(\.order), [42, 43, 44, 45])
        XCTAssertEqual(projection.records.map(\.isSelected), [false, true, false, false])
        XCTAssertTrue(projection.blockers.contains(.transactionalInstallerUnavailable))
        XCTAssertEqual(String(reflecting: projection), "IOSReceiveCoreDataProjection.Cohort(<redacted>)")

        let stored = try persistAndRefetch(projection.records)
        for (expected, actual) in zip(projection.records, stored) {
            XCTAssertEqual(actual.wallet, expected.wallet)
            XCTAssertEqual(actual.isSelected, expected.isSelected)
            XCTAssertEqual(actual.order, expected.order)
            XCTAssertEqual(actual.displayPreferences, expected.displayPreferences)
            XCTAssertEqual(actual.recordState, .supported)
            XCTAssertFalse(try XCTUnwrap(actual.wallet).hasBackup)
        }
        let combined = try XCTUnwrap(stored[0].wallet)
        XCTAssertEqual(combined.chainAccounts.count, 1)
        XCTAssertEqual(combined.favouriteChainIds, [genesis])
        XCTAssertEqual(combined.assetKeysOrder, [])
        XCTAssertEqual(combined.unusedChainIds, ["retained-unused"])
        XCTAssertEqual(combined.networkManagmentFilter, "")
        XCTAssertEqual(combined.assetsVisibility, [AssetVisibility(assetId: "asset-a", hidden: true)])
        XCTAssertEqual(stored[0].displayPreferences?.assetFilterOptions, ["future-filter"])
        XCTAssertEqual(stored[0].displayPreferences?.zeroBalanceAssetsHidden, true)
        XCTAssertNil(stored[1].wallet?.substratePublicKey)
        XCTAssertNotNil(stored[1].wallet?.ethereumPublicKey)
        XCTAssertEqual(stored[2].wallet?.legacyTonAccount, try LegacyNativeTonFixture.account())
    }

    func testLegacySubstrateAndNamedChainRetainOriginalPublicIdentity() throws {
        let root = try substrateSlot(role: Codec.Role.legacySubstrate)
        var solana = try substrateSlot(role: Codec.Role.chainAccount, key: UniversalWalletRegistry.solanaMainnet.chainId)
        solana.fields += [.init(id: 9, value: []), .init(id: 10, value: [1])]
        solana.fields.sort { $0.id < $1.id }
        let projected = try project(.init(selectedIndex: 0, wallets: [wallet(1, slots: [root, solana])]))
        let stored = try XCTUnwrap(try persistAndRefetch(projected.records)[0].wallet)
        XCTAssertEqual(stored.substrateAccountId, try Data(root.value(1)).publicKeyToAccountId())
        XCTAssertEqual(stored.substrateCryptoType, CryptoType.ed25519.rawValue)
        XCTAssertEqual(stored.chainAccounts.first?.chainId, UniversalWalletRegistry.solanaMainnet.chainId)
        XCTAssertEqual(stored.chainAccounts.first?.publicKey, try Data(solana.value(1)))
    }

    func testRawAndroidTonAddressMapsToSameReleasedTONIdentity() throws {
        var ton = try tonSlot()
        ton.fields = try ton.fields.map { field in
            if field.id == 7 {
                return try .init(id: 7, value: [0] + Array(TonAddressCodec.v4R2AccountHash(publicKey: Data(ton.value(1)))))
            }
            return field.id == 14 ? .init(id: 14, value: [1]) : field
        }
        let projected = try project(.init(selectedIndex: 0, wallets: [wallet(1, slots: [ton])]))
        let stored = try XCTUnwrap(try persistAndRefetch(projected.records)[0].wallet?.legacyTonAccount)
        XCTAssertEqual(stored.address, try LegacyNativeTonFixture.account().address)
        XCTAssertEqual(stored.publicKey, try LegacyNativeTonFixture.account().publicKey)
    }

    func testWatchCohortCannotBeMisrepresentedAsSignedOrPartiallyReturned() throws {
        let root = try substrateSlot()
        let watch = try Codec.Slot(role: Codec.Role.watchIdentity, key: "0000", fields: [
            .init(id: 1, value: root.value(1)), .init(id: 7, value: root.value(7)),
            .init(id: 8, value: [2]), .init(id: 22, value: [1])
        ])
        let snapshot = Codec.Snapshot(selectedIndex: 0, wallets: [wallet(1, slots: [root]), wallet(2, slots: [watch])])
        XCTAssertThrowsError(try project(snapshot)) {
            XCTAssertEqual($0 as? Projection.ProjectionError, .unmappedWatchIdentity)
        }
    }

    func testUnmappedDisplayAndWalletStatesFailWithoutDroppingValues() throws {
        let root = try evmSlot()
        for metadataID: UInt8 in [10, 11] {
            let snapshot = Codec.Snapshot(selectedIndex: 0, wallets: [wallet(
                1, slots: [root], metadata: [.init(id: metadataID, value: [])]
            )])
            XCTAssertThrowsError(try project(snapshot)) {
                XCTAssertEqual($0 as? Projection.ProjectionError, .unmappedForeignDisplayPreferences)
            }
        }
        let uninitialized = Codec.Wallet(
            portableID: [UInt8](repeating: 1, count: 16), sourcePosition: 0,
            initialized: false, name: "Uninitialized", metadata: [], slots: [root]
        )
        XCTAssertThrowsError(try project(.init(selectedIndex: 0, wallets: [uninitialized]))) {
            XCTAssertEqual($0 as? Projection.ProjectionError, .unmappedWalletState)
        }
        let falseFavorite = Codec.Slot(role: Codec.Role.favoriteChain, key: genesis, fields: [.init(id: 10, value: [0])])
        XCTAssertThrowsError(try project(.init(selectedIndex: 0, wallets: [wallet(1, slots: [root, falseFavorite])]))) {
            XCTAssertEqual($0 as? Projection.ProjectionError, .unmappedFavoriteState)
        }
    }

    func testUnrepresentableRootCombinationAndUnapprovedChainFailClosed() throws {
        XCTAssertThrowsError(try project(.init(selectedIndex: 0, wallets: [
            wallet(1, slots: [substrateSlot(), tonSlot()])
        ]))) {
            XCTAssertEqual($0 as? Projection.ProjectionError, .unsupportedRootCombination)
        }
        var chain = try substrateSlot(role: Codec.Role.chainAccount, key: String(repeating: "cd", count: 32))
        chain.fields += [.init(id: 9, value: []), .init(id: 10, value: [1])]
        chain.fields.sort { $0.id < $1.id }
        XCTAssertThrowsError(try project(.init(selectedIndex: 0, wallets: [wallet(1, slots: [evmSlot(), chain])]))) {
            XCTAssertEqual($0 as? Projection.ProjectionError, .unmappedChainAccount)
        }
    }

    func testCurrencyResolutionRejectsUnknownAndAmbiguousLocalCatalog() throws {
        let snapshot = try Codec.Snapshot(selectedIndex: 0, wallets: [wallet(
            1, slots: [evmSlot()], metadata: [.init(id: 3, value: Array("absent".utf8))]
        )])
        XCTAssertThrowsError(try project(snapshot)) {
            XCTAssertEqual($0 as? Projection.ProjectionError, .unknownCurrency)
        }
        let encoded = try Codec.encode(snapshot)
        XCTAssertThrowsError(try Projection.project(
            semantic: encoded, journal: journal(encoded, snapshot: snapshot),
            approvedSubstrateGenesisIDs: [genesis], existingOrders: [],
            currencies: [defaultCurrency, defaultCurrency], defaultCurrencyID: defaultCurrency.id
        )) {
            XCTAssertEqual($0 as? Projection.ProjectionError, .invalidCurrencyCatalog)
        }
    }

    func testSelectedLocalCurrencyAndFavoriteOrderSurvivePersistence() throws {
        let currency = Currency(id: "eur", symbol: "EUR", name: "Euro", icon: "local-eur", isSelected: false)
        let favorites = ["second", "first"]
        let snapshot = try Codec.Snapshot(selectedIndex: 0, wallets: [wallet(
            1, slots: [evmSlot()], metadata: [
                .init(id: 3, value: Array(currency.id.utf8)),
                .init(id: 6, value: IOSPortableWalletSemanticDraftAdapter.stringList(favorites))
            ]
        )])
        let encoded = try Codec.encode(snapshot)
        let projection = try Projection.project(
            semantic: encoded, journal: journal(encoded, snapshot: snapshot),
            approvedSubstrateGenesisIDs: [], existingOrders: [],
            currencies: [defaultCurrency, currency], defaultCurrencyID: defaultCurrency.id
        )
        let stored = try XCTUnwrap(try persistAndRefetch(projection.records).first?.wallet)
        XCTAssertEqual(stored.selectedCurrency, currency)
        XCTAssertEqual(stored.favouriteChainIds, favorites)
    }

    func testChangedJournalOrSignerCannotProduceAfterImage() throws {
        var snapshot = try Codec.Snapshot(selectedIndex: 0, wallets: [wallet(1, slots: [evmSlot()])])
        let encoded = try Codec.encode(snapshot)
        let originalJournal = journal(encoded, snapshot: snapshot)
        snapshot.wallets[0].slots[0].fields[1].value[0] ^= 1
        let changed = try Codec.encode(snapshot)
        XCTAssertThrowsError(try Projection.project(
            semantic: changed, journal: originalJournal, approvedSubstrateGenesisIDs: [genesis],
            existingOrders: [], currencies: [defaultCurrency], defaultCurrencyID: defaultCurrency.id
        ))
        XCTAssertThrowsError(try project(snapshot))
        XCTAssertThrowsError(try project(
            .init(selectedIndex: 0, wallets: [wallet(1, slots: [evmSlot()])]),
            existingOrders: [UInt32(Int32.max)]
        ))
    }
}

private extension IOSReceiveCoreDataProjectionTests {
    func project(_ snapshot: Codec.Snapshot, existingOrders: [UInt32] = []) throws -> Projection.Cohort {
        let encoded = try Codec.encode(snapshot)
        return try Projection.project(
            semantic: encoded, journal: journal(encoded, snapshot: snapshot),
            approvedSubstrateGenesisIDs: [genesis], existingOrders: existingOrders,
            currencies: [defaultCurrency], defaultCurrencyID: defaultCurrency.id
        )
    }

    func journal(_ encoded: Data, snapshot: Codec.Snapshot) -> Journal.Record {
        Journal.Record(
            schemaVersion: 1, transactionID: "22222222-2222-4222-8222-222222222222",
            semanticSHA256: Data(SHA256.hash(data: encoded)), selectedIndex: snapshot.selectedIndex,
            wallets: snapshot.wallets.enumerated().map { index, wallet in
                .init(metaID: String(format: "11111111-1111-4111-8111-%012d", index), portableID: Data(wallet.portableID))
            },
            keys: [], phase: .staging
        )
    }

    func wallet(_ id: UInt8, slots: [Codec.Slot], metadata: [Codec.Metadata] = []) -> Codec.Wallet {
        Codec.Wallet(
            portableID: [UInt8](repeating: id, count: 16), sourcePosition: UInt32.max,
            initialized: true, name: "Wallet \(id)", metadata: metadata, slots: slots
        )
    }

    func evmSlot() throws -> Codec.Slot {
        let key = Data(repeating: 0x11, count: 32)
        let publicKey = try SECKeyFactory().derive(fromPrivateKey: SECPrivateKey(rawData: key)).publicKey().rawData()
        return try .init(role: Codec.Role.evmRoot, key: "", fields: [
            .init(id: 1, value: Array(publicKey)), .init(id: 2, value: Array(key)),
            .init(id: 7, value: Array(publicKey.ethereumAddressFromPublicKey())), .init(id: 11, value: [0])
        ])
    }

    func substrateSlot(role: UInt8 = Codec.Role.substrateRoot, key: String = "") throws -> Codec.Slot {
        let secret = Data(repeating: 0x12, count: 32)
        let pair = try EDKeyFactory().derive(fromSeed: secret)
        let publicKey = pair.publicKey().rawData()
        let accountID = try publicKey.publicKeyToAccountId()
        let serializedAccount = role == Codec.Role.legacySubstrate
            ? try Data(accountID.toAddress(using: .substrate(42)).utf8) : accountID
        return .init(role: role, key: key, fields: [
            .init(id: 1, value: Array(publicKey)), .init(id: 2, value: Array(secret)),
            .init(id: 7, value: Array(serializedAccount)), .init(id: 8, value: [2]),
            .init(id: 11, value: [role == Codec.Role.legacySubstrate ? 5 : 0])
        ])
    }

    func tonSlot() throws -> Codec.Slot {
        let account = try LegacyNativeTonFixture.account()
        return try .init(role: Codec.Role.tonRoot, key: "", fields: [
            .init(id: 1, value: Array(account.publicKey)), .init(id: 2, value: Array(LegacyNativeTonFixture.privateKey())),
            .init(id: 7, value: Array(account.serializedAddress)), .init(id: 11, value: [0]),
            .init(id: 12, value: Array(LegacyNativeTonFixture.phrase.utf8)),
            .init(id: 13, value: [2]), .init(id: 14, value: [2])
        ])
    }

    func displayMetadata() throws -> [Codec.Metadata] {
        try [
            .init(id: 1, value: IOSPortableWalletSemanticDraftAdapter.stringList([])),
            .init(id: 2, value: IOSPortableWalletSemanticDraftAdapter.stringList(["retained-unused"])),
            .init(id: 3, value: Array(defaultCurrency.id.utf8)), .init(id: 4, value: []),
            .init(id: 5, value: IOSPortableWalletSemanticDraftAdapter.visibilityMap([
                AssetVisibility(assetId: "asset-a", hidden: true)
            ])),
            .init(id: 7, value: IOSPortableWalletSemanticDraftAdapter.stringList(["future-filter"])),
            .init(id: 8, value: [1]), .init(id: 9, value: [0])
        ]
    }

    func persistAndRefetch(_ records: [MetaAccountSelectionModel]) throws -> [MetaAccountSelectionModel] {
        let queue = OperationQueue()
        let facade = UserDataStorageTestFacade()
        let repository = facade.createRepository(
            filter: nil, sortDescriptors: [NSSortDescriptor(key: "order", ascending: true)],
            mapper: AnyCoreDataMapper(MetaAccountSelectionMapper(captureDisplayPreferences: true))
        )
        let save = repository.saveOperation({ records }, { [] })
        queue.addOperations([save], waitUntilFinished: true)
        _ = try XCTUnwrap(save.result).get()
        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions())
        queue.addOperations([fetch], waitUntilFinished: true)
        return try XCTUnwrap(fetch.result).get()
    }
}
