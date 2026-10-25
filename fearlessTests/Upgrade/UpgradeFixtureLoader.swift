import CoreData
import CryptoKit
import Foundation

/// Loads the upgrade fixtures bundled with the test target.
enum UpgradeFixtureLoader {
    static let historicalStoreModelsDirectory = "HistoricalStoreModels"

    static var bundle: Bundle {
        Bundle(for: BundleToken.self)
    }

    /// IK-1: every Core Data store model a released build opened its stores
    /// with, compiled from the verbatim Git blob (see
    /// `fearless/Common/Storage/HistoricalStoreModels/README.md`).
    static func historicalStoreModels() throws -> [HistoricalStoreModel] {
        guard let url = bundle.url(
            forResource: "manifest",
            withExtension: "json",
            subdirectory: historicalStoreModelsDirectory
        ) else {
            throw FixtureError.missingResource("\(historicalStoreModelsDirectory)/manifest.json")
        }

        return try JSONDecoder().decode(HistoricalStoreModelManifest.self, from: Data(contentsOf: url)).models
    }

    /// The compiled test fixture for a manifest entry.
    static func fixtureModelURL(for model: HistoricalStoreModel) throws -> URL {
        let subdirectory = "\(historicalStoreModelsDirectory)/Fixtures"
        guard let url = bundle.url(forResource: model.resource, withExtension: "mom", subdirectory: subdirectory) else {
            throw FixtureError.missingResource("\(subdirectory)/\(model.resource).mom")
        }

        return url
    }

    static func fixtureModel(for model: HistoricalStoreModel) throws -> NSManagedObjectModel {
        let url = try fixtureModelURL(for: model)
        guard let managedObjectModel = NSManagedObjectModel(contentsOf: url) else {
            throw FixtureError.unreadableModel(url)
        }

        return managedObjectModel
    }

    /// Schema digest used by the manifest: the first 16 hex characters of
    /// SHA-256 over the entity version hashes sorted by entity name, joined as
    /// `name=base64(hash)` with `;`. Models with equal digests open the same stores.
    static func schemaDigest(of model: NSManagedObjectModel) -> String {
        let hashes = model.entityVersionHashesByName
        let canonical = hashes.keys.sorted()
            .map { name in "\(name)=\(hashes[name]?.base64EncodedString() ?? "")" }
            .joined(separator: ";")

        return String(
            SHA256.hash(data: Data(canonical.utf8))
                .map { String(format: "%02x", $0) }
                .joined()
                .prefix(16)
        )
    }
}

extension UpgradeFixtureLoader {
    enum FixtureError: Error {
        case missingResource(String)
        case unreadableModel(URL)
    }

    struct HistoricalStoreModelManifest: Decodable {
        let format: String
        let version: Int
        let models: [HistoricalStoreModel]
    }

    struct HistoricalStoreModel: Decodable {
        enum Store: String, Decodable {
            case substrate
            case user
        }

        enum Tier: String, Decodable {
            case appStore
            case testFlight
            case development
        }

        struct Drops: Decodable, Equatable {
            let entities: [String]
            let attributes: [String]
        }

        struct Commit: Decodable {
            let commit: String
            let title: String
        }

        let store: Store
        let digest: String
        let resource: String
        let gitBlob: String
        let equivalentGitBlobs: [String]
        let versionChecksum: String
        let tier: Tier
        let releases: [String]
        let interimTags: [String]
        let heads: [Commit]
        let developmentCommits: [Commit]
        /// The lineage or compatibility resource the release already bundles with this digest.
        let matchesBundled: String?
        /// The lineage model this store migrates to first; such models ship in the app.
        let landing: String?
        let allowedDrops: Drops?
        /// Constants for mandatory destination attributes the source model lacks.
        let requiredConstants: [String: String]
        /// Inventoried, but migrated only through guided recovery.
        let excluded: String?

        var isAppBundled: Bool {
            landing != nil
        }
    }

    private final class BundleToken {}
}
