import Foundation

enum UserStorageVersion: String, CaseIterable {
    case version1 = "UserDataModel"
    case version2 = "MultiassetUserDataModel"
    case version3 = "MultiassetUserDataModel_v2"
    case version4 = "MultiassetUserDataModel_v3"
    case version5 = "MultiassetUserDataModel_v4"
    case version6 = "MultiassetUserDataModel_v5"
    case version7 = "MultiassetUserDataModel_v6"
    case version8 = "MultiassetUserDataModel_v7"
    case version9 = "MultiassetUserDataModel_v8"
    case version10 = "MultiassetUserDataModel_v9"
    case version11 = "MultiassetUserDataModel_v10"
    case version12 = "MultiassetUserDataModel_v11"

    // Verbatim models of stores written by TestFlight builds whose model was
    // later edited in place (see HistoricalStoreModels/README.md). Each case
    // is named after its schema digest and lands on the lineage model of its
    // schema family, so the real downstream hops only see data that has not
    // been through them.

    /// TestFlight 2.0.8.4, 2.0.8.12–2.0.8.14 and 2.0.9.1. Lacks only
    /// `CDMetaAccount.unusedChainIds`.
    case historical0470cf6e = "UserHistorical_0470cf6eb7223e09"
    /// TestFlight 2.2.2.3–2.2.2.4, 2.2.3.1, 2.2.4.13, 2.2.5.2 and 2.2.5.6.
    /// Already stores `CDAssetVisibility`; lacks only
    /// `CDMetaAccount.zeroBalanceAssetsHidden`.
    case historical399fe7c2 = "UserHistorical_399fe7c2a5ba8b2c"
    /// TestFlight 2.4.1.1–2.4.1.2. Stores `CDMetaAccount.hasBackup` as an
    /// optional value, which those builds read as `false` when empty.
    case historicalEa8584ec = "UserHistorical_ea8584ece2603f2a"

    /// Schema shipped by the ecosystem/TON app line. It is a migration source,
    /// not an active destination for this app.
    case version13 = "LegacyEcosystemUserDataModel_v12"
    /// Superset schema that accepts both the public v11 and ecosystem v12
    /// layouts without dropping ecosystem or TON fields.
    case version14 = "CompatibleUserDataModel_v13"

    static let historicalModelDirectory = "HistoricalStoreModels"

    private static let historicalResourcePrefix = "UserHistorical_"

    static var current: UserStorageVersion {
        // Explicit, so that declaring a case after version14 can never move
        // the migration target.
        .version14
    }

    func nextVersion() -> UserStorageVersion? {
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
            return .version9
        case .version9:
            return .version10
        case .version10:
            return .version11
        case .version11:
            return .version12
        case .version12:
            return .version14
        case .historical0470cf6e:
            return .version4
        case .historical399fe7c2:
            // Lands after the assetIdsEnabled -> CDAssetVisibility hop, which
            // this schema has already made.
            return .version10
        case .historicalEa8584ec:
            return .version11
        case .version13:
            return .version14
        case .version14:
            return nil
        }
    }

    var isCompatibilityResource: Bool {
        switch self {
        case .version13, .version14:
            return true
        default:
            return isHistoricalResource
        }
    }

    /// Shipped in the app's `HistoricalStoreModels` folder rather than in the
    /// lineage model directory.
    var isHistoricalResource: Bool {
        rawValue.hasPrefix(Self.historicalResourcePrefix)
    }

    func modelURL(
        in bundle: Bundle,
        legacyModelDirectory: String
    ) -> URL? {
        let subdirectory: String?
        if isHistoricalResource {
            subdirectory = Self.historicalModelDirectory
        } else {
            subdirectory = isCompatibilityResource ? nil : legacyModelDirectory
        }

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
