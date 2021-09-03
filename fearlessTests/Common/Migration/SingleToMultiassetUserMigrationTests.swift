import XCTest
import CoreData
import RobinHood
import FearlessUtils
import IrohaCrypto
import SoraKeystore
@testable import fearless

class SingleToMultiassetUserMigrationTests: XCTestCase {
    struct Account {
        let address: String
        let cryptoType: UInt8
        let name: String
        let privateKey: Data
        let publicKey: Data
        let entropy: Data?
        let derivationPath: String?
        let seed: Data?
    }

    let databaseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("CoreData")
    let databaseName = UUID().uuidString + ".sqlite"
    let modelDirectory = "UserDataModel.momd"

    var storeURL: URL {
        databaseDirectory.appendingPathComponent(databaseName)
    }

    func testUserMigration() throws {
        // given

        let oldService = createCoreDataService(for: .version1)
        let keystore = InMemoryKeychain()
        let settings = InMemorySettingsManager()

        let networkType: UInt16 = 0
        let cryptoType: fearless.CryptoType = .sr25519
        let privateKey = Data.random(of: 32)!
        let publicKey = Data.random(of: 32)!
        let name = "Username"
        let identifier = try SS58AddressFactory().address(fromAccountId: publicKey, type: networkType)

        let dbSemaphore = DispatchSemaphore(value: 0)

        // when

        try keystore.saveKey(privateKey, with: KeystoreTag.secretKeyTagForAddress(identifier))

        oldService.performAsync { (context, error) in
            defer {
                dbSemaphore.signal()
            }

            guard let context = context else {
                return
            }

            let account = NSEntityDescription.insertNewObject(
                forEntityName: "CDAccountItem",
                into: context
            )

            account.setValue(identifier, forKey: "identifier")
            account.setValue(name, forKeyPath: "username")
            account.setValue(networkType, forKey: "networkType")
            account.setValue(cryptoType.rawValue, forKey: "cryptoType")
            account.setValue(publicKey, forKey: "publicKey")
            account.setValue(0, forKeyPath: "order")

            try! context.save()
        }

        dbSemaphore.wait()

        try oldService.close()

        let migrator = UserStorageMigrator(
            targetVersion: .version2,
            storeURL: storeURL,
            modelDirectory: modelDirectory,
            keystore: keystore,
            settings: settings,
            fileManager: FileManager.default
        )

        migrator.performMigration()

        let newService = createCoreDataService(for: .version2)

        var metaId: String?

        let newSemaphore = DispatchSemaphore(value: 0)

        newService.performAsync { (context, error) in
            defer {
                newSemaphore.signal()
            }

            let request = NSFetchRequest<NSManagedObject>(entityName: "CDMetaAccount")
            let results = try! context?.fetch(request)

            metaId = results?.first?.value(forKey: "metaId") as? String
        }

        newSemaphore.wait()

        XCTAssertNotNil(metaId)

        try newService.close()
        try newService.drop()
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

    private func generateAccount(
        hasEntropy: Bool,
        hasSeed: Bool,
        hasDerivationPath: Bool
    ) throws -> Account {

    }
}
