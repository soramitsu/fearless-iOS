import XCTest
@testable import fearless
import CoreData
import RobinHood
import SoraKeystore
import SSFModels

/// IK-11 upgrade path: a wallet store written by 3.7.4, carried through 4.0.4's own
/// migration and use, then opened by this release. Every network keeps the address 4.0.4
/// showed; per-chain accounts that 4.0.4 hid are offered, not switched to; a damaged
/// per-chain row costs only that row. The same 3.7.4 store opened directly (no 4.0.x in
/// between) keeps the addresses 3.7.4 showed.
final class PerChainAccountUpgradeContinuityTests: XCTestCase {
    private let polkadot = ChainAccountRecordsFixture.chain(id: ChainAccountRecordsFixture.polkadotChainId)
    private let kusama = ChainAccountRecordsFixture.chain(id: ChainAccountRecordsFixture.kusamaChainId, prefix: 2)
    private let moonbeam = ChainAccountRecordsFixture.chain(
        id: ChainAccountRecordsFixture.moonbeamChainId, ethereumBased: true
    )

    private var directory: URL!
    private var appBundle: Bundle { Bundle(for: UserDataStorageFacade.self) }

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PerChainAccountUpgradeContinuityTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        try super.tearDownWithError()
    }

    // MARK: - 3.7.4 -> 4.0.4 -> this release

    func testStoreCarriedThrough404_whenOpened_thenEveryNetworkKeepsThe404AddressAndHiddenAccountsAreOffered() throws {
        let store374 = directory.appendingPathComponent("374/UserDataModel.sqlite")
        try writeStoreAs374(at: store374)

        let store = directory.appendingPathComponent("live/UserDataModel.sqlite")
        try replay404Migration(from: store374, to: store)
        // What users did in 4.0.4: a Kusama account imported into "Main", and a new
        // Moonbeam account imported into "Imported later", which 4.0.4 wrote over the
        // hidden 3.7.4 Moonbeam row because it looked rows up by network only.
        try use(store, model: model(.version13)) { context in
            try self.apply404ChainAccountImport(Fixture.mainKusama, ecosystem: "substrate", to: "main", in: context)
            try self.apply404ChainAccountImport(
                Fixture.importedMoonbeam, ecosystem: "ethereumBased", to: "imported-later", in: context
            )
        }
        let shownBy404 = try addressesShownBy404(in: store)

        _ = try makeMigrator(storeURL: store).performMigration()
        let rowsBeforeReading = try chainRows(in: store, model: model(.version14))
        let facade = try FileBackedUserStorageFacade(storeURL: store, model: model(.version14))

        let wallets = try fetchWallets(in: facade)
        XCTAssertEqual(Set(wallets.map(\.metaId)), ["main", "no-ethereum", "imported-later", "damaged"])

        // Every address 4.0.4 showed is the one this release uses.
        for (walletId, chains) in shownBy404 {
            let wallet = try XCTUnwrap(wallets.first { $0.metaId == walletId }, walletId)
            for (chain, accountId) in chains {
                XCTAssertEqual(
                    wallet.fetch(for: chain.accountRequest())?.accountId, accountId,
                    "\(walletId) on \(chain.name) must keep the address 4.0.4 showed"
                )
            }
        }

        let main = try XCTUnwrap(wallets.first { $0.metaId == "main" })
        XCTAssertEqual(main.fetch(for: polkadot.accountRequest())?.accountId, Fixture.mainRoot.substrateAccountId)
        XCTAssertEqual(main.fetch(for: moonbeam.accountRequest())?.accountId, Fixture.mainRoot.ethereumAddress)
        XCTAssertEqual(main.fetch(for: kusama.accountRequest())?.accountId, Fixture.mainKusama.accountId)

        // 4.0.4 showed no Moonbeam account for a wallet without an Ethereum account of its
        // own; the per-chain account is the only one it has, so it is used.
        let noEthereum = try XCTUnwrap(wallets.first { $0.metaId == "no-ethereum" })
        XCTAssertNil(shownBy404["no-ethereum"]?.first { $0.0.chainId == moonbeam.chainId })
        XCTAssertEqual(noEthereum.fetch(for: moonbeam.accountRequest())?.accountId, Fixture.noEthereumMoonbeam.accountId)

        let imported = try XCTUnwrap(wallets.first { $0.metaId == "imported-later" })
        XCTAssertEqual(imported.fetch(for: moonbeam.accountRequest())?.accountId, Fixture.importedMoonbeam.accountId)

        // One damaged row costs only that row.
        let damaged = try XCTUnwrap(wallets.first { $0.metaId == "damaged" })
        XCTAssertEqual(damaged.fetch(for: polkadot.accountRequest())?.accountId, Fixture.damagedRoot.substrateAccountId)

        // The hidden accounts are offered, labelled with the right kind of account.
        let report = try fetchReport(in: facade)
        XCTAssertEqual(report.unavailableWalletCount, 0)
        XCTAssertEqual(Set(report.alternatives(for: "main")), [Fixture.mainPolkadot, Fixture.mainMoonbeam])
        XCTAssertTrue(try XCTUnwrap(report.alternatives(for: "main").first { $0.chainId == moonbeam.chainId }).ethereumBased)
        XCTAssertEqual(report.alternatives(for: "damaged"), [Fixture.damagedKusama])
        XCTAssertEqual(report.alternatives(for: "no-ethereum"), [])
        XCTAssertEqual(report.alternatives(for: "imported-later"), [])
        XCTAssertEqual(report.unusableChainAccountCount, 1)

        // The user is told once.
        let tracker = StoredWalletRecordsNoticeTracker(settings: InMemorySettingsManager())
        XCTAssertEqual(
            tracker.pendingNotices(for: report),
            [
                .recordsNotShown(wallets: 0, chainAccounts: 1),
                .storedChainAccounts(walletIds: ["damaged", "main"], walletNames: ["Damaged row", "Main"])
            ]
        )
        tracker.acknowledgeRecordsNotShown(in: report)
        tracker.acknowledgeStoredChainAccounts(in: report)
        XCTAssertEqual(tracker.pendingNotices(for: report), [])

        // The selected wallet comes up with the same addresses, and reading wrote nothing.
        let settings = SelectedWalletSettings(storageFacade: facade, operationQueue: OperationQueue())
        let selected = try XCTUnwrap(try setup(settings))
        XCTAssertEqual(selected.metaId, "main")
        XCTAssertEqual(selected.fetch(for: polkadot.accountRequest())?.accountId, Fixture.mainRoot.substrateAccountId)
        XCTAssertEqual(try chainRows(in: store, model: model(.version14)), rowsBeforeReading)

        // Choosing the older Polkadot account works and can be undone; nothing is removed.
        let switched = try select(
            .chainAccount(accountId: Fixture.mainPolkadot.accountId, publicKey: Fixture.mainPolkadot.publicKey),
            chainId: polkadot.chainId, walletId: "main", facade: facade
        )
        XCTAssertEqual(switched.fetch(for: polkadot.accountRequest())?.accountId, Fixture.mainPolkadot.accountId)
        let restored = try select(.walletAccount, chainId: polkadot.chainId, walletId: "main", facade: facade)
        XCTAssertEqual(restored.fetch(for: polkadot.accountRequest())?.accountId, Fixture.mainRoot.substrateAccountId)
        XCTAssertEqual(
            try chainRows(in: store, model: model(.version14)).map(\.identity),
            rowsBeforeReading.map(\.identity)
        )
    }

    // MARK: - 3.7.4 -> this release

    func testStoreFrom374_whenOpenedDirectly_thenEveryNetworkKeepsThe374Address() throws {
        let store = directory.appendingPathComponent("374/UserDataModel.sqlite")
        try writeStoreAs374(at: store)

        _ = try makeMigrator(storeURL: store).performMigration()
        let facade = try FileBackedUserStorageFacade(storeURL: store, model: model(.version14))
        let wallets = try fetchWallets(in: facade)

        let main = try XCTUnwrap(wallets.first { $0.metaId == "main" })
        XCTAssertEqual(main.fetch(for: polkadot.accountRequest())?.accountId, Fixture.mainPolkadot.accountId)
        XCTAssertEqual(main.fetch(for: moonbeam.accountRequest())?.accountId, Fixture.mainMoonbeam.accountId)
        XCTAssertEqual(main.fetch(for: kusama.accountRequest())?.accountId, Fixture.mainRoot.substrateAccountId)

        let imported = try XCTUnwrap(wallets.first { $0.metaId == "imported-later" })
        XCTAssertEqual(imported.fetch(for: moonbeam.accountRequest())?.accountId, Fixture.importedOldMoonbeam.accountId)

        let damaged = try XCTUnwrap(wallets.first { $0.metaId == "damaged" })
        XCTAssertEqual(damaged.fetch(for: kusama.accountRequest())?.accountId, Fixture.damagedKusama.accountId)
        XCTAssertEqual(damaged.fetch(for: polkadot.accountRequest())?.accountId, Fixture.damagedRoot.substrateAccountId)

        let report = try fetchReport(in: facade)
        XCTAssertEqual(report.wallets.flatMap(\.alternatives), [])
        XCTAssertEqual(report.unusableChainAccountCount, 1)
    }
}

// MARK: - Before 2.0.9 -> this release

extension PerChainAccountUpgradeContinuityTests {
    /// Releases 2.0.0 to 2.0.8 stored per-chain rows before `ethereumBased` existed
    /// (MultiassetUserDataModel_v2), and 2.0.9 to 3.7.4 added the field only when they saved
    /// the wallet again; all of them used such a row for its network. The shipped hops bring
    /// the row to the current model without either label, the shape 4.0.x left the rows it
    /// hid. Opened directly, without 4.0.x in between, the store keeps the per-chain
    /// addresses those releases showed.
    func testStoreWrittenBefore209_whenOpenedDirectly_thenThePerChainAccountsStayInUse() throws {
        let store = directory.appendingPathComponent("208/UserDataModel.sqlite")
        try FileManager.default.createDirectory(
            at: store.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let root = Fixture.mainRoot
        try use(store, model: model(.version3), create: true) { context in
            let wallet = NSEntityDescription.insertNewObject(forEntityName: "CDMetaAccount", into: context)
            wallet.setValue(root.metaId, forKey: "metaId")
            wallet.setValue(root.name, forKey: "name")
            wallet.setValue(true, forKey: "isSelected")
            wallet.setValue(Int32(1), forKey: "order")
            wallet.setValue(root.substrateAccountId.toHex(), forKey: "substrateAccountId")
            wallet.setValue(root.substratePublicKey, forKey: "substratePublicKey")
            wallet.setValue(Int16(CryptoType.sr25519.rawValue), forKey: "substrateCryptoType")
            wallet.setValue(root.ethereumAddress?.toHex(), forKey: "ethereumAddress")
            wallet.setValue(root.ethereumPublicKey, forKey: "ethereumPublicKey")
            wallet.setValue(true, forKey: "canExportEthereumMnemonic")
            for account in [Fixture.mainPolkadot, Fixture.mainMoonbeam] {
                let row = NSEntityDescription.insertNewObject(forEntityName: "CDChainAccount", into: context)
                row.setValue(account.chainId, forKey: "chainId")
                row.setValue(account.accountId.toHex(), forKey: "accountId")
                row.setValue(account.publicKey, forKey: "publicKey")
                row.setValue(Int16(account.cryptoType), forKey: "cryptoType")
                row.setValue(wallet, forKey: "metaAccount")
            }
        }

        XCTAssertTrue(try makeMigrator(storeURL: store).performMigration())
        let facade = try FileBackedUserStorageFacade(storeURL: store, model: model(.version14))
        let main = try XCTUnwrap(try fetchWallets(in: facade).first { $0.metaId == root.metaId })

        XCTAssertEqual(main.fetch(for: polkadot.accountRequest())?.accountId, Fixture.mainPolkadot.accountId)
        XCTAssertEqual(main.fetch(for: moonbeam.accountRequest())?.accountId, Fixture.mainMoonbeam.accountId)
        XCTAssertEqual(main.fetch(for: kusama.accountRequest())?.accountId, root.substrateAccountId)
        XCTAssertEqual(try fetchReport(in: facade).wallets.flatMap(\.alternatives), [])

        // Only the label those releases read was written; accounts, keys and networks are as stored.
        let rows = try chainRows(in: store, model: model(.version14))
        XCTAssertEqual(
            Set(rows.map(\.identity)),
            Set([Fixture.mainPolkadot, Fixture.mainMoonbeam].map {
                "\(root.metaId)|\($0.chainId)|\($0.accountId.toHex())|\($0.publicKey.toHex())|\($0.cryptoType)"
            })
        )
        XCTAssertEqual(rows.first { $0.chainId == polkadot.chainId }?.ethereumBased, false)
        XCTAssertEqual(rows.first { $0.chainId == moonbeam.chainId }?.ethereumBased, true)
        XCTAssertTrue(rows.allSatisfy { $0.ecosystem == nil })
    }

    func testOnlyStoresThatNeverRanTheEcosystemLineAreLabelled() {
        XCTAssertFalse(UserStorageMigrator.predatesEcosystemLine(.version13), "4.0.x hid rows; its choice stays")
        XCTAssertFalse(UserStorageMigrator.predatesEcosystemLine(.version14))
        for version in UserStorageVersion.allCases where ![.version13, .version14].contains(version) {
            XCTAssertTrue(UserStorageMigrator.predatesEcosystemLine(version), version.rawValue)
        }
    }
}

// MARK: - Fixture

private enum Fixture {
    struct Root {
        let metaId: String
        let name: String
        let substrateAccountId: Data
        let substratePublicKey: Data
        let ethereumAddress: Data?
        let ethereumPublicKey: Data?
    }

    static let mainRoot = root("main", "Main", marker: 0x10, ethereum: true)
    static let noEthereumRoot = root("no-ethereum", "Before Ethereum", marker: 0x20, ethereum: false)
    static let importedRoot = root("imported-later", "Imported later", marker: 0x30, ethereum: true)
    static let damagedRoot = root("damaged", "Damaged row", marker: 0x40, ethereum: true)

    static let mainPolkadot = ChainAccountRecordsFixture.substrateAccount(
        chainId: ChainAccountRecordsFixture.polkadotChainId, marker: 0x51
    )
    static let mainMoonbeam = ChainAccountRecordsFixture.ethereumAccount(
        chainId: ChainAccountRecordsFixture.moonbeamChainId, marker: 0x53
    )
    static let mainKusama = ChainAccountRecordsFixture.substrateAccount(
        chainId: ChainAccountRecordsFixture.kusamaChainId, marker: 0x55
    )
    static let noEthereumMoonbeam = ChainAccountRecordsFixture.ethereumAccount(
        chainId: ChainAccountRecordsFixture.moonbeamChainId, marker: 0x61
    )
    static let importedOldMoonbeam = ChainAccountRecordsFixture.ethereumAccount(
        chainId: ChainAccountRecordsFixture.moonbeamChainId, marker: 0x71
    )
    static let importedMoonbeam = ChainAccountRecordsFixture.ethereumAccount(
        chainId: ChainAccountRecordsFixture.moonbeamChainId, marker: 0x73
    )
    static let damagedKusama = ChainAccountRecordsFixture.substrateAccount(
        chainId: ChainAccountRecordsFixture.kusamaChainId, marker: 0x81
    )
    /// Written by an older or interim build: a 31-byte key that no release validated.
    static let damagedPolkadot = ChainAccountModel(
        chainId: ChainAccountRecordsFixture.polkadotChainId,
        accountId: Data(repeating: 0x83, count: 32),
        publicKey: Data(repeating: 0x84, count: 31),
        cryptoType: CryptoType.sr25519.rawValue,
        ethereumBased: false
    )

    /// The wallets and per-chain rows of the 3.7.4 store.
    static let wallets: [(Root, [ChainAccountModel])] = [
        (mainRoot, [mainPolkadot, mainMoonbeam]),
        (noEthereumRoot, [noEthereumMoonbeam]),
        (importedRoot, [importedOldMoonbeam]),
        (damagedRoot, [damagedKusama, damagedPolkadot])
    ]

    private static func root(_ metaId: String, _ name: String, marker: UInt8, ethereum: Bool) -> Root {
        Root(
            metaId: metaId,
            name: name,
            substrateAccountId: Data(repeating: marker, count: 32),
            substratePublicKey: Data(repeating: marker &+ 1, count: 32),
            ethereumAddress: ethereum ? Data(repeating: marker &+ 2, count: 20) : nil,
            ethereumPublicKey: ethereum ? Data(repeating: marker &+ 3, count: 33) : nil
        )
    }
}

/// Copies of the 4.0.4 policies in `MultiAssetV12.xcmappingmodel` (fearless-iOS tag 4.0.4,
/// `CDChainAccountMigrationPolicyV12.swift` and `CDMetaAccountMigrationPolicy.swift`), so
/// the store is carried exactly as 4.0.4 carried it.
@objc(IK11Shipped404ChainAccountMigrationPolicy)
private final class Shipped404ChainAccountMigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)

        if let destination = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [sInstance]
        ).first {
            destination.setValue(nil, forKey: "ecosystem")
        }
    }
}

@objc(IK11Shipped404MetaAccountMigrationPolicy)
private final class Shipped404MetaAccountMigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(forSource: sInstance, in: mapping, manager: manager)

        if let destination = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [sInstance]
        ).first {
            destination.setValue(nil, forKey: "tonAddress")
            destination.setValue(nil, forKey: "tonContractVersion")
            destination.setValue(nil, forKey: "tonPublicKey")

            if destination.value(forKey: "substrateAccountId") == nil {
                destination.setValue(nil, forKey: "substrateAccountId")
            }
            if destination.value(forKey: "substrateCryptoType") == nil {
                destination.setValue(0, forKey: "substrateCryptoType")
            }
            if destination.value(forKey: "substratePublicKey") == nil {
                destination.setValue(nil, forKey: "substratePublicKey")
            }
        }
    }
}

// MARK: - Steps

private extension PerChainAccountUpgradeContinuityTests {
    struct ChainRow: Equatable {
        let walletId: String
        let chainId: String?
        let accountId: String?
        let publicKey: Data?
        let cryptoType: Int16
        let ethereumBased: Bool?
        let ecosystem: String?

        var identity: String {
            "\(walletId)|\(chainId ?? "")|\(accountId ?? "")|\(publicKey?.toHex() ?? "")|\(cryptoType)"
        }
    }

    func model(_ version: UserStorageVersion) throws -> NSManagedObjectModel {
        let url = try XCTUnwrap(
            version.modelURL(in: appBundle, legacyModelDirectory: UserStorageParams.modelDirectory),
            "Missing model \(version.rawValue)"
        )
        return try XCTUnwrap(NSManagedObjectModel(contentsOf: url))
    }

    /// Writes the store the way 3.7.4's mapper did: every row carries `ethereumBased`.
    func writeStoreAs374(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try use(url, model: model(.version12), create: true) { context in
            for (index, (root, chainAccounts)) in Fixture.wallets.enumerated() {
                let wallet = NSEntityDescription.insertNewObject(forEntityName: "CDMetaAccount", into: context)
                wallet.setValue(root.metaId, forKey: "metaId")
                wallet.setValue(root.name, forKey: "name")
                wallet.setValue(root.metaId == "main", forKey: "isSelected")
                wallet.setValue(Int32(index + 1), forKey: "order")
                wallet.setValue(root.substrateAccountId.toHex(), forKey: "substrateAccountId")
                wallet.setValue(root.substratePublicKey, forKey: "substratePublicKey")
                wallet.setValue(Int16(CryptoType.sr25519.rawValue), forKey: "substrateCryptoType")
                wallet.setValue(root.ethereumAddress?.toHex(), forKey: "ethereumAddress")
                wallet.setValue(root.ethereumPublicKey, forKey: "ethereumPublicKey")
                wallet.setValue(true, forKey: "canExportEthereumMnemonic")
                wallet.setValue(false, forKey: "hasBackup")
                wallet.setValue(false, forKey: "zeroBalanceAssetsHidden")
                wallet.setValue(NSArray(), forKey: "favouriteChainIds")

                for account in chainAccounts {
                    let row = NSEntityDescription.insertNewObject(forEntityName: "CDChainAccount", into: context)
                    row.setValue(account.chainId, forKey: "chainId")
                    row.setValue(account.accountId.toHex(), forKey: "accountId")
                    row.setValue(account.publicKey, forKey: "publicKey")
                    row.setValue(Int16(account.cryptoType), forKey: "cryptoType")
                    row.setValue(account.ethereumBased, forKey: "ethereumBased")
                    row.setValue(wallet, forKey: "metaAccount")
                }
            }
        }
    }

    /// 4.0.4's own v11 -> v12 step: the model change Core Data infers plus 4.0.4's policies.
    func replay404Migration(from source: URL, to destination: URL) throws {
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let sourceModel = try model(.version12)
        let destinationModel = try model(.version13)
        let mapping = try NSMappingModel.inferredMappingModel(
            forSourceModel: sourceModel, destinationModel: destinationModel
        )
        for entityMapping in mapping.entityMappings {
            switch entityMapping.destinationEntityName {
            case "CDChainAccount":
                entityMapping.entityMigrationPolicyClassName = NSStringFromClass(
                    Shipped404ChainAccountMigrationPolicy.self
                )
            case "CDMetaAccount":
                entityMapping.entityMigrationPolicyClassName = NSStringFromClass(
                    Shipped404MetaAccountMigrationPolicy.self
                )
            default:
                break
            }
        }

        try NSMigrationManager(sourceModel: sourceModel, destinationModel: destinationModel).migrateStore(
            from: source, sourceType: NSSQLiteStoreType, options: nil, with: mapping,
            toDestinationURL: destination, destinationType: NSSQLiteStoreType, destinationOptions: nil
        )
    }

    /// 4.0.4's `MetaAccountMapper.populate` for one per-chain account: the first row with the
    /// same chain id is reused, otherwise a row is added; the ecosystem is always written.
    func apply404ChainAccountImport(
        _ account: ChainAccountModel,
        ecosystem: String,
        to walletId: String,
        in context: NSManagedObjectContext
    ) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDMetaAccount")
        request.predicate = NSPredicate(format: "metaId == %@", walletId)
        let wallet = try XCTUnwrap(try context.fetch(request).first)
        let rows = (wallet.value(forKey: "chainAccounts") as? NSSet)?.allObjects as? [NSManagedObject] ?? []
        let row = rows.first { $0.value(forKey: "chainId") as? String == account.chainId } ?? {
            let newRow = NSEntityDescription.insertNewObject(forEntityName: "CDChainAccount", into: context)
            newRow.setValue(wallet, forKey: "metaAccount")
            return newRow
        }()
        row.setValue(account.accountId.toHex(), forKey: "accountId")
        row.setValue(account.chainId, forKey: "chainId")
        row.setValue(Int16(account.cryptoType), forKey: "cryptoType")
        row.setValue(account.publicKey, forKey: "publicKey")
        row.setValue(ecosystem, forKey: "ecosystem")
    }

    /// What 4.0.4 showed (shared-features-spm 53e0a4b `MetaAccountMapper` and
    /// `MetaAccountModel.fetch(for:)`): rows without a known ecosystem were not mapped, and a
    /// network without a mapped row used the wallet's own account of its kind.
    func addressesShownBy404(in store: URL) throws -> [String: [(ChainModel, AccountId)]] {
        let knownEcosystems: Set<String> = ["substrate", "ethereumBased", "ethereum", "ton"]
        var result: [String: [(ChainModel, AccountId)]] = [:]
        try use(store, model: model(.version13)) { context in
            let wallets = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDMetaAccount"))
            for wallet in wallets {
                let metaId = try XCTUnwrap(wallet.value(forKey: "metaId") as? String)
                let rows = (wallet.value(forKey: "chainAccounts") as? NSSet)?.allObjects as? [NSManagedObject] ?? []
                let mapped = rows.filter { ($0.value(forKey: "ecosystem") as? String).map(knownEcosystems.contains) == true }
                for chain in [self.polkadot, self.kusama, self.moonbeam] {
                    let accountIdHex: String?
                    if let row = mapped.first(where: { $0.value(forKey: "chainId") as? String == chain.chainId }) {
                        accountIdHex = row.value(forKey: "accountId") as? String
                    } else {
                        accountIdHex = wallet.value(
                            forKey: chain.isEthereumBased ? "ethereumAddress" : "substrateAccountId"
                        ) as? String
                    }
                    if let accountIdHex {
                        result[metaId, default: []].append((chain, try Data(hexStringSSF: accountIdHex)))
                    }
                }
            }
        }
        return result
    }

    func makeMigrator(storeURL: URL) -> UserStorageMigrator {
        UserStorageMigrator(
            targetVersion: .version14,
            storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: InMemoryKeychain(),
            settings: InMemorySettingsManager(),
            fileManager: .default,
            modelBundle: appBundle
        )
    }

    func fetchWallets(in facade: StorageFacadeProtocol) throws -> [MetaAccountModel] {
        let repository = AccountRepositoryFactory(storageFacade: facade)
            .createMetaAccountRepository(for: nil, sortDescriptors: [])
        let fetch = repository.fetchAllOperation(with: RepositoryFetchOptions(
            includesProperties: true, includesSubentities: true
        ))
        OperationQueue().addOperations([fetch], waitUntilFinished: true)
        return try XCTUnwrap(fetch.result).get()
    }

    func fetchReport(in facade: StorageFacadeProtocol) throws -> StoredWalletRecordsReport {
        let operation = StoredWalletRecordsInspector(storageFacade: facade).fetchReportOperation()
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        return try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
    }

    func select(
        _ selection: ChainAccountSelection,
        chainId: String,
        walletId: String,
        facade: StorageFacadeProtocol
    ) throws -> MetaAccountModel {
        let operation = StoredWalletRecordsInspector(storageFacade: facade).selectChainAccountOperation(
            ChainAccountSelectionUpdate(chainId: chainId, selection: selection), walletId: walletId
        )
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        return try operation.extractResultData(throwing: BaseOperationError.parentOperationCancelled)
    }

    func setup(_ settings: SelectedWalletSettings) throws -> MetaAccountModel? {
        let completed = expectation(description: "selected wallet setup completes")
        var setupResult: Result<MetaAccountModel?, Error>?
        settings.setup(runningCompletionIn: .main) { result in
            setupResult = result
            completed.fulfill()
        }
        wait(for: [completed], timeout: 10)
        return try XCTUnwrap(setupResult).get()
    }

    func chainRows(in store: URL, model: NSManagedObjectModel) throws -> [ChainRow] {
        var rows: [ChainRow] = []
        try use(store, model: model) { context in
            rows = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDChainAccount")).map {
                ChainRow(
                    walletId: ($0.value(forKey: "metaAccount") as? NSManagedObject)?.value(forKey: "metaId") as? String ?? "",
                    chainId: $0.value(forKey: "chainId") as? String,
                    accountId: $0.value(forKey: "accountId") as? String,
                    publicKey: $0.value(forKey: "publicKey") as? Data,
                    cryptoType: ($0.value(forKey: "cryptoType") as? NSNumber)?.int16Value ?? 0,
                    ethereumBased: ($0.value(forKey: "ethereumBased") as? NSNumber)?.boolValue,
                    ecosystem: $0.value(forKey: "ecosystem") as? String
                )
            }
            .sorted { $0.identity < $1.identity }
        }
        return rows
    }

    func use(
        _ url: URL,
        model: NSManagedObjectModel,
        create: Bool = false,
        body: @escaping (NSManagedObjectContext) throws -> Void
    ) throws {
        if !create {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Missing store \(url.path)")
        }
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType, configurationName: nil, at: url,
            options: [
                NSMigratePersistentStoresAutomaticallyOption: false,
                NSInferMappingModelAutomaticallyOption: false
            ]
        )
        defer { try? coordinator.remove(store) }

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        var bodyError: Error?
        context.performAndWait {
            do {
                try body(context)
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                bodyError = error
            }
        }
        if let bodyError {
            throw bodyError
        }
    }
}

// MARK: - File-backed storage

/// Opens a migrated store file the way the app does, with the app's managed object classes.
private final class FileBackedUserStorageFacade: StorageFacadeProtocol {
    let databaseService: CoreDataServiceProtocol

    init(storeURL: URL, model: NSManagedObjectModel) throws {
        databaseService = try FileBackedCoreDataService(storeURL: storeURL, model: model)
    }

    func createRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> CoreDataRepository<T, U> where T: Identifiable, U: NSManagedObject {
        CoreDataRepository(
            databaseService: databaseService, mapper: mapper, filter: filter, sortDescriptors: sortDescriptors
        )
    }

    func createAsyncRepository<T, U>(
        filter: NSPredicate?,
        sortDescriptors: [NSSortDescriptor],
        mapper: AnyCoreDataMapper<T, U>
    ) -> AsyncCoreDataRepositoryDefault<T, U> where T: Identifiable, U: NSManagedObject {
        AsyncCoreDataRepositoryDefault(
            databaseService: databaseService, mapper: mapper, filter: filter, sortDescriptors: sortDescriptors
        )
    }
}

private final class FileBackedCoreDataService: CoreDataServiceProtocol {
    let configuration: CoreDataServiceConfigurationProtocol
    private let context: NSManagedObjectContext

    init(storeURL: URL, model: NSManagedObjectModel) throws {
        let classNames: [String: String] = [
            "CDAccountInfo": NSStringFromClass(CDAccountInfo.self),
            "CDAssetVisibility": NSStringFromClass(CDAssetVisibility.self),
            "CDChainAccount": NSStringFromClass(CDChainAccount.self),
            "CDChainSettings": NSStringFromClass(CDChainSettings.self),
            "CDCurrency": NSStringFromClass(CDCurrency.self),
            "CDCustomChainNode": NSStringFromClass(CDCustomChainNode.self),
            "CDMetaAccount": NSStringFromClass(CDMetaAccount.self)
        ]
        let appModel = try XCTUnwrap(model.copy() as? NSManagedObjectModel)
        for entity in appModel.entities {
            if let name = entity.name, let className = classNames[name] {
                entity.managedObjectClassName = className
            }
        }

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: appModel)
        try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL,
            options: [
                NSMigratePersistentStoresAutomaticallyOption: false,
                NSInferMappingModelAutomaticallyOption: false
            ]
        )
        context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        configuration = CoreDataServiceConfiguration(modelURL: storeURL, storageType: .inMemory)
    }

    func performAsync(block: @escaping CoreDataContextInvocationBlock) {
        context.perform {
            block(self.context, nil)
        }
    }

    func close() throws {}

    func drop() throws {}
}
