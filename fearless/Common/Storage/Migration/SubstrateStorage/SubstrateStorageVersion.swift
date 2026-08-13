import Foundation

enum SubstrateStorageVersion: String, CaseIterable {
    case version1 = "SubstrateDataModel"
    case version2 = "SubstrateDataModel_v2"
    case version3 = "SubstrateDataModel_v3"
    case version4 = "SubstrateDataModel_v4"
    case version5 = "SubstrateDataModel_v5"
    case version6 = "SubstrateDataModel_v6"
    case version7 = "SubstrateDataModel_v7"
    case version8 = "SubstrateDataModel_v8"
    /// Immutable model shipped by the public App Store 4.0.4 line.
    case legacyPublicVersion8 = "LegacyPublicSubstrateDataModel_v8"
    /// Immutable model shipped by the public App Store 4.0.5/4.1.0 line.
    case legacyPublicVersion9 = "LegacyPublicSubstrateDataModel_v9"
    /// Lossless union of the modernized v8 and both public App Store schemas.
    case version10 = "SubstrateDataModel_v10"

    static var current: SubstrateStorageVersion {
        guard let currentVersion = allCases.last else {
            fatalError("Unable to find current storage version")
        }

        return currentVersion
    }

    func nextVersion() -> SubstrateStorageVersion? {
        switch self {
        case .version1:
            return .version2
        case .version2:
            return .version3
        case .version3:
            return .version4
        case .version4:
            return .version5
        case .version5:
            return .version6
        case .version6:
            return .version7
        case .version7:
            return .version8
        case .version8:
            return .version10
        case .legacyPublicVersion8:
            return .version10
        case .legacyPublicVersion9:
            return .version10
        case .version10:
            return nil
        }
    }

    var isCompatibilityResource: Bool {
        switch self {
        case .legacyPublicVersion8, .legacyPublicVersion9:
            return true
        default:
            return false
        }
    }

    var requiresStartupGraphBounds: Bool {
        switch self {
        case .version8,
             .legacyPublicVersion8,
             .legacyPublicVersion9,
             .version10:
            return true
        default:
            return false
        }
    }

    func modelURL(
        in bundle: Bundle,
        modelDirectory: String
    ) -> URL? {
        let subdirectory = isCompatibilityResource ? nil : modelDirectory

        return bundle.url(
            forResource: rawValue,
            withExtension: "omo",
            subdirectory: subdirectory
        ) ?? bundle.url(
            forResource: rawValue,
            withExtension: "mom",
            subdirectory: subdirectory
        )
    }
}
