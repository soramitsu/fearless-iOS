import CoreData
import CryptoKit
import XCTest
@testable import fearless

/// Guards the IOSUX-0 project scaffolding: resources land in the right bundle under the names the
/// later packages look them up by, and test fixtures never ship in the app.
final class ProjectResourcesTests: XCTestCase {
    private let testFixtureFolders = [
        "Registry",
        "LegacyVisibility",
        "HistoricalStoreModels",
        "ReleaseFixtures",
        "UpgradeFixtures"
    ]

    func testCanonicalGroupsResourceIsBundled() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "canonical-asset-groups.v1", withExtension: "json"))
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let catalog = try XCTUnwrap(object as? [String: Any])

        XCTAssertEqual(catalog["format"] as? String, "fearless.canonical-asset-groups")
        XCTAssertEqual(catalog["version"] as? Int, 1)
        XCTAssertNotNil(catalog["groups"] as? [Any])
    }

    func testHistoricalStoreModelsFolderIsBundledUnderItsLookupName() throws {
        // Historical store models are resolved with `subdirectory: "HistoricalStoreModels"`.
        let resources = try XCTUnwrap(Bundle.main.resourceURL)

        XCTAssertTrue(isDirectory(resources.appendingPathComponent("HistoricalStoreModels")))
    }

    func testRegistrySnapshotFixtureIsBundledByteForByte() throws {
        let url = try XCTUnwrap(Bundle(for: ProjectResourcesTests.self).url(
            forResource: "chains_v13_20261009", withExtension: "json", subdirectory: "Registry"
        ))

        XCTAssertEqual(
            SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined(),
            "fa6f0e23cd87dfb3e5536980591dd22ae30e49bf59d04dc2a0b31fc53237ea66"
        )
    }

    func testFixtureFoldersAreBundledInTestTarget() throws {
        let resources = try XCTUnwrap(Bundle(for: ProjectResourcesTests.self).resourceURL)

        for folder in testFixtureFolders {
            XCTAssertTrue(isDirectory(resources.appendingPathComponent(folder)), folder)
        }
    }

    func testFixtureFoldersDoNotShipInApp() throws {
        let resources = try XCTUnwrap(Bundle.main.resourceURL)

        for folder in testFixtureFolders where folder != "HistoricalStoreModels" {
            XCTAssertFalse(isDirectory(resources.appendingPathComponent(folder)), folder)
        }
        XCTAssertNil(Bundle.main.url(forResource: "chains_v13_20261009", withExtension: "json"))
        XCTAssertNil(Bundle.main.url(forResource: "manifest", withExtension: "json", subdirectory: "HistoricalStoreModels"))
    }

    func testHistoricalStoreModelsShipExactlyTheLandingModels() throws {
        // IK-1: only models the release does not otherwise recognise ship in the app.
        let models = try UpgradeFixtureLoader.historicalStoreModels()
        let expected = Set(models.filter(\.isAppBundled).map(\.resource))
        let shipped = Set(
            (Bundle.main.urls(forResourcesWithExtension: "mom", subdirectory: "HistoricalStoreModels") ?? [])
                .map { $0.deletingPathExtension().lastPathComponent }
        )

        XCTAssertFalse(expected.isEmpty)
        XCTAssertEqual(shipped, expected)
    }

    func testHistoricalStoreModelsLoadWithTheirManifestIdentity() throws {
        for model in try UpgradeFixtureLoader.historicalStoreModels() {
            let fixture = try UpgradeFixtureLoader.fixtureModel(for: model)

            XCTAssertEqual(UpgradeFixtureLoader.schemaDigest(of: fixture), model.digest, model.resource)
            if #available(iOS 17.0, *) {
                // Core Data only computes a stable checksum once the model is in use.
                let coordinator = NSPersistentStoreCoordinator(managedObjectModel: fixture)
                XCTAssertEqual(fixture.versionChecksum, model.versionChecksum, model.resource)
                withExtendedLifetime(coordinator) {}
            }

            guard model.isAppBundled else { continue }

            let url = try XCTUnwrap(
                Bundle.main.url(forResource: model.resource, withExtension: "mom", subdirectory: "HistoricalStoreModels"),
                model.resource
            )
            let shipped = try XCTUnwrap(NSManagedObjectModel(contentsOf: url), model.resource)
            XCTAssertEqual(UpgradeFixtureLoader.schemaDigest(of: shipped), model.digest, model.resource)
        }
    }

    func testHistoricalFixturesMatchTheModelsTheAppAlreadyBundles() throws {
        // The offline audit compares against this checkout's sources; this checks
        // the models the app really resolves (User lineage from shared-features).
        for model in try UpgradeFixtureLoader.historicalStoreModels() {
            guard let bundledName = model.matchesBundled else { continue }

            let url = bundledModelURL(named: bundledName, store: model.store)
            let bundled = try XCTUnwrap(url.flatMap(NSManagedObjectModel.init(contentsOf:)), bundledName)

            XCTAssertEqual(UpgradeFixtureLoader.schemaDigest(of: bundled), model.digest, model.resource)
        }
    }

    private func bundledModelURL(named name: String, store: UpgradeFixtureLoader.HistoricalStoreModel.Store) -> URL? {
        switch store {
        case .substrate:
            return SubstrateStorageVersion(rawValue: name)?.modelURL(
                in: .main,
                modelDirectory: SubstrateStorageParams.modelDirectory
            )
        case .user:
            return UserStorageVersion(rawValue: name)?.modelURL(
                in: .main,
                legacyModelDirectory: UserStorageParams.modelDirectory
            )
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
