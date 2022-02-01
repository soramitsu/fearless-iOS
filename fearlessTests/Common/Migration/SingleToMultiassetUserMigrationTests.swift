import XCTest
import CoreData
import RobinHood
import FearlessUtils
import IrohaCrypto
import SoraKeystore
@testable import fearless

class SingleToMultiassetUserMigrationTests: XCTestCase {
    struct OldAccount {
        let address: String
        let cryptoType: UInt8
        let name: String
        let privateKey: Data
        let publicKey: Data
        let entropy: Data?
        let derivationPath: String?
        let seed: Data?
    }

    struct NewEntity {
        let metaId: String
        let name: String
        let isSelected: Bool
        let substrateAccountId: String
        let substratePublicKey: Data
        let substrateCryptoType: UInt8
        let ethereumAddress: String?
        let ethereumPublicKey: Data?
        let order: Int32
    }

    let databaseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("CoreData")
    let databaseName = UUID().uuidString + ".sqlite"
    let modelDirectory = "UserDataModel.momd"

    var storeURL: URL {
        databaseDirectory.appendingPathComponent(databaseName)
    }

    override func setUp() {
        super.setUp()

        try? FileManager.default.removeItem(at: databaseDirectory)
    }

    override func tearDown() {
        super.tearDown()

        try? FileManager.default.removeItem(at: databaseDirectory)
    }

    func testMigrationForCreatedAccountWithoutDerivPath() {
        do {
            try performTestUserMigration(hasEntropy: true, hasSeed: true, hasDerivationPath: false)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMigrationForCreatedAccountWithDerivPath() {
        do {
            try performTestUserMigration(hasEntropy: true, hasSeed: true, hasDerivationPath: true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMigrationForImportedWithSeedAccountWithoutDerivPath() {
        do {
            try performTestUserMigration(hasEntropy: false, hasSeed: true, hasDerivationPath: false)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMigrationForImportedWithSeedAccountWithDerivPath() {
        do {
            try performTestUserMigration(hasEntropy: false, hasSeed: true, hasDerivationPath: true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMigrationForImportedWithJSONAccountWithoutDerivPath() {
        do {
            try performTestUserMigration(hasEntropy: false, hasSeed: false, hasDerivationPath: false)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMigrationForImportedWithJSONAccountWithDerivPath() {
        do {
            try performTestUserMigration(hasEntropy: false, hasSeed: false, hasDerivationPath: true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func performTestUserMigration(hasEntropy: Bool, hasSeed: Bool, hasDerivationPath: Bool) throws {
        // given

        let keystore = InMemoryKeychain()
        let settings = InMemorySettingsManager()

        let accounts = try generateAndSaveOldAccounts(
            count: 10,
            keystore: keystore,
            hasEntropy: hasEntropy,
            hasSeed: hasSeed,
            hasDerivationPath: hasDerivationPath
        )

        // we put some dummy data for serialized settings just to make sure that it is cleared
        settings.set(value: Data(), for: SettingsKey.selectedAccount.rawValue)
        settings.set(value: Data(), for: SettingsKey.selectedConnection.rawValue)

        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: modelDirectory,
            keystore: keystore,
            settings: settings,
            fileManager: FileManager.default
        )

        guard migrator.requiresMigration() else {
            XCTFail("Migration not required")
            return
        }

        migrator.performMigration()

        // then

        let newEntities = try fetchNewEntities()

        let addressFactory = SS58AddressFactory()

        for account in accounts {
            guard let newEntity = newEntities.first(where: { $0.substratePublicKey == account.publicKey }) else {
                XCTFail("Missing account after migration")
                continue
            }

            XCTAssertNotNil(newEntity.metaId)
            XCTAssertEqual(account.name, newEntity.name)
            XCTAssertEqual(account.publicKey, newEntity.substratePublicKey)
            XCTAssertEqual(account.cryptoType, newEntity.substrateCryptoType)

            let oldAccountId = try addressFactory.accountId(from: account.address)
            XCTAssertEqual(oldAccountId.toHex(), newEntity.substrateAccountId)

            let entropyExistence = try keystore.checkKey(for: KeystoreTagV2.entropyTagForMetaId(newEntity.metaId))
            let substrateSeedExistence = try keystore.checkKey(
                for: KeystoreTagV2.substrateSeedTagForMetaId(newEntity.metaId)
            )

            let ethSeedExistence = try keystore.checkKey(
                for: KeystoreTagV2.ethereumSeedTagForMetaId(newEntity.metaId)
            )

            let ethPrivateKeyExistence = try keystore.checkKey(
                for: KeystoreTagV2.ethereumSecretKeyTagForMetaId(newEntity.metaId)
            )

            let substrateDerivPathExistence = try keystore.checkKey(
                for: KeystoreTagV2.substrateDerivationTagForMetaId(newEntity.metaId)
            )

            let ethDerivPathExistence = try keystore.checkKey(
                for: KeystoreTagV2.ethereumDerivationTagForMetaId(newEntity.metaId)
            )

            if hasEntropy {
                let migratedEntropy = try keystore.fetchKey(for: KeystoreTagV2.entropyTagForMetaId(newEntity.metaId))
                XCTAssertEqual(account.entropy, migratedEntropy)
                XCTAssertNotNil(newEntity.ethereumPublicKey)
                XCTAssertNotNil(newEntity.ethereumAddress)
                XCTAssertTrue(ethSeedExistence)
                XCTAssertTrue(ethPrivateKeyExistence)
                XCTAssertTrue(ethDerivPathExistence)
            } else {
                XCTAssertNil(newEntity.ethereumPublicKey)
                XCTAssertNil(newEntity.ethereumAddress)
                XCTAssertFalse(entropyExistence)
                XCTAssertFalse(ethSeedExistence)
                XCTAssertFalse(ethPrivateKeyExistence)
                XCTAssertFalse(ethDerivPathExistence)
            }

            if hasSeed {
                let migratedSeed = try keystore.fetchKey(
                    for: KeystoreTagV2.substrateSeedTagForMetaId(newEntity.metaId)
                )
                XCTAssertEqual(account.seed, migratedSeed)
            } else {
                XCTAssertFalse(substrateSeedExistence)
            }

            if hasDerivationPath {
                let migratedDerivationPath = try keystore.fetchKey(
                    for: KeystoreTagV2.substrateDerivationTagForMetaId(newEntity.metaId)
                )

                XCTAssertEqual(account.derivationPath, String(data: migratedDerivationPath, encoding: .utf8))

            } else {
                XCTAssertFalse(substrateDerivPathExistence)
            }
        }

        let orders = Set(newEntities.map { $0.order })
        XCTAssertEqual(newEntities.count, orders.count)

        let hasSelected = newEntities.contains { $0.isSelected }
        XCTAssertTrue(hasSelected)

        XCTAssertNil(settings.data(for: SettingsKey.selectedAccount.rawValue))
        XCTAssertNil(settings.data(for: SettingsKey.selectedConnection.rawValue))
    }

    // MARK: Private

    private func createModelURL(for version: UserStorageVersion) -> URL {
        let bundle = Bundle.main

        return bundle.url(
            forResource: version.rawValue,
            withExtension: "mom",
            subdirectory: modelDirectory
        )!
    }

    private func createCoreDataService(for version: UserStorageVersion) -> CoreDataServiceProtocol {
        let modelURL = createModelURL(for: version)

        let persistentSettings = CoreDataPersistentSettings(
            databaseDirectory: databaseDirectory,
            databaseName: databaseName,
            incompatibleModelStrategy: .ignore
        )

        let configuration = CoreDataServiceConfiguration(
            modelURL: modelURL,
            storageType: .persistent(settings: persistentSettings)
        )

        return CoreDataService(configuration: configuration)
    }

    private func fetchNewEntities() throws -> [NewEntity] {
        let dbService = createCoreDataService(for: .version2)
        let semaphore = DispatchSemaphore(value: 0)
        var newEntities: [NewEntity]?

        dbService.performAsync { (context, error) in
            defer {
                semaphore.signal()
            }

            let request = NSFetchRequest<NSManagedObject>(entityName: "CDMetaAccount")
            let results = try! context?.fetch(request)

            newEntities = results?.map { entity in
                let metaId = entity.value(forKey: "metaId") as? String
                let name = entity.value(forKey: "name") as? String
                let isSelected = entity.value(forKey: "isSelected") as? Bool
                let substrateAccountId = entity.value(forKey: "substrateAccountId") as? String
                let substratePublicKey = entity.value(forKey: "substratePublicKey") as? Data
                let substrateCryptoType = entity.value(forKey: "substrateCryptoType") as? UInt8
                let ethereumAddress = entity.value(forKey: "ethereumAddress") as? String
                let ethereumPublicKey = entity.value(forKey: "ethereumPublicKey") as? Data
                let order = entity.value(forKey: "order") as? Int32

                return NewEntity(
                    metaId: metaId!,
                    name: name!,
                    isSelected: isSelected!,
                    substrateAccountId: substrateAccountId!,
                    substratePublicKey: substratePublicKey!,
                    substrateCryptoType: substrateCryptoType!,
                    ethereumAddress: ethereumAddress,
                    ethereumPublicKey: ethereumPublicKey,
                    order: order!
                )
            }
        }

        semaphore.wait()

        try dbService.close()

        return newEntities ?? []
    }

    private func generateAndSaveOldAccounts(
        count: Int,
        keystore: KeystoreProtocol,
        hasEntropy: Bool,
        hasSeed: Bool,
        hasDerivationPath: Bool
    ) throws -> [OldAccount] {
        let dbService = createCoreDataService(for: .version1)

        let accounts = try (0..<count).map { _ in
            try generateOldAccount(hasEntropy: hasEntropy, hasSeed: hasSeed, hasDerivationPath: hasDerivationPath)
        }

        let semaphore = DispatchSemaphore(value: 0)

        dbService.performAsync { (context, error) in
            defer {
                semaphore.signal()
            }

            guard let context = context else {
                return
            }

            accounts.forEach { account in
                let entity = NSEntityDescription.insertNewObject(
                    forEntityName: "CDAccountItem",
                    into: context
                )

                entity.setValue(account.address, forKey: "identifier")
                entity.setValue(account.name, forKeyPath: "username")
                entity.setValue(0, forKey: "networkType")
                entity.setValue(account.cryptoType, forKey: "cryptoType")
                entity.setValue(account.publicKey, forKey: "publicKey")
                entity.setValue(0, forKeyPath: "order")
            }

            try! context.save()
        }

        semaphore.wait()

        try accounts.forEach { account in
            try keystore.saveKey(account.privateKey, with: KeystoreTag.secretKeyTagForAddress(account.address))

            if let seed = account.seed {
                try keystore.saveKey(seed, with: KeystoreTag.seedTagForAddress(account.address))
            }

            if let entropy = account.entropy {
                try keystore.saveKey(entropy, with: KeystoreTag.entropyTagForAddress(account.address))
            }

            if let derivationPath = account.derivationPath {
                try keystore.saveKey(
                    derivationPath.data(using: .utf8)!, with: KeystoreTag.deriviationTagForAddress(account.address)
                )
            }
        }

        return accounts
    }

    private func generateOldAccount(
        hasEntropy: Bool,
        hasSeed: Bool,
        hasDerivationPath: Bool
    ) throws -> OldAccount {
        let mnemonicGenerator = IRMnemonicCreator(language: .english)
        let mnemonic = try mnemonicGenerator.randomMnemonic(.entropy160)

        let seedFactory = SeedFactory(mnemonicLanguage: .english)
        let seedResult = try seedFactory.deriveSeed(from: mnemonic.toString(), password: "")

        let derivationPath = hasDerivationPath ? "//0/1" : nil

        let chaincodes = try derivationPath.map { try SubstrateJunctionFactory().parse(path: $0).chaincodes } ?? []

        let keypair = try SR25519KeypairFactory().createKeypairFromSeed(
            seedResult.seed.miniSeed,
            chaincodeList: chaincodes
        )

        let address = try SS58AddressFactory().address(fromAccountId: keypair.publicKey().rawData(), type: 0)

        return OldAccount(
            address: address,
            cryptoType: 0,
            name: UUID().uuidString,
            privateKey: keypair.privateKey().rawData(),
            publicKey: keypair.publicKey().rawData(),
            entropy: hasEntropy ? mnemonic.entropy() : nil,
            derivationPath: derivationPath,
            seed: hasSeed ? seedResult.seed : nil
        )
    }
}
