import CoreData
@testable import fearless
import XCTest

final class RetainedSubstrateContactSalvageTests: XCTestCase {
    func testContactsFromEveryShippedHistoricalModelAreReadWithoutChangingRetainedBytes() throws {
        var tested = 0
        for entry in try UpgradeFixtureLoader.historicalStoreModels().filter({ $0.store == .substrate }) {
            let model = try UpgradeFixtureLoader.fixtureModel(for: entry)
            guard let entity = model.entitiesByName["CDContact"],
                  Set(["address", "chainId", "name"]).isSubset(of: Set(entity.attributesByName.keys)) else { continue }
            // NSManagedObject avoids invoking today's custom class against a
            // historical model; all schema definitions are verbatim shipped blobs.
            for entity in model.entities {
                entity.managedObjectClassName = "NSManagedObject"
            }
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("RetainedContactTests-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: root) }
            let storeURL = root.appendingPathComponent(SubstrateStorageParams.databaseName)
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
            let store = try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: [NSSQLitePragmasOption: ["journal_mode": "DELETE"]]
            )
            let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            context.persistentStoreCoordinator = coordinator
            let object = NSEntityDescription.insertNewObject(forEntityName: "CDContact", into: context)
            object.setValue("historical-recipient", forKey: "address")
            object.setValue("historical-chain", forKey: "chainId")
            object.setValue("Original contact", forKey: "name")
            try context.save()
            try coordinator.remove(store)
            let original = try Data(contentsOf: storeURL)
            XCTAssertEqual(
                RetainedSubstrateContactSalvage.contacts(from: storeURL),
                [Contact(name: "Original contact", address: "historical-recipient", chainId: "historical-chain")],
                entry.digest
            )
            XCTAssertEqual(try Data(contentsOf: storeURL), original, entry.digest)
            tested += 1
        }
        XCTAssertGreaterThan(tested, 0)
    }

    func testDedupeNeverOverwritesCurrentContactOrDuplicatesArchivedAddress() {
        let current = Contact(name: "Current", address: "same", chainId: "new-chain")
        let old = Contact(name: "Old", address: "same", chainId: "old-chain")
        let missing = Contact(name: "Missing", address: "new", chainId: "old-chain")
        XCTAssertEqual(RetainedSubstrateContactSalvage.missing([old, missing, missing], from: [current]), [missing])
    }

    func testMissingStoreOrContactTableIsANoOp() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertTrue(RetainedSubstrateContactSalvage.contacts(from: url).isEmpty)
        try Data("unreadable historical store".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(RetainedSubstrateContactSalvage.contacts(from: url).isEmpty)
    }
}
