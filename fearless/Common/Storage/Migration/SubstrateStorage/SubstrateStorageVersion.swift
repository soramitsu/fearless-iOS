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

    // Verbatim models of stores written by builds whose shipped model was
    // later edited in place (see HistoricalStoreModels/README.md). Each case
    // is named after its schema digest and lands on the lineage model of its
    // schema family, so the real downstream hops only see data that has not
    // been through them.

    /// App Store 0.4.0–1.2.2.
    case historical27378408 = "SubstrateHistorical_27378408dc2e9402"
    /// App Store 1.6.0.
    case historicalD7130246 = "SubstrateHistorical_d713024629483ef3"
    /// App Store 1.7.0–1.10.x and 1.99.0.
    case historical021514c3 = "SubstrateHistorical_021514c396c2d844"
    /// App Store 2.0.0–2.0.3.
    case historical6ca82510 = "SubstrateHistorical_6ca82510c9ee52ee"
    /// App Store 2.0.4.
    case historical5cffa3d6 = "SubstrateHistorical_5cffa3d6ae6c920b"
    /// App Store 2.0.7.
    case historicalDdb3684b = "SubstrateHistorical_ddb3684b41b1ea24"
    /// TestFlight 2.0.8.4–2.0.9.1.
    case historicalF83c370e = "SubstrateHistorical_f83c370eecf5cb6f"
    /// App Store 2.0.8–2.0.9.
    case historical244dfde3 = "SubstrateHistorical_244dfde33ea8f2ba"
    /// App Store 2.0.11.
    case historical92b1571a = "SubstrateHistorical_92b1571afd8bc9e9"
    /// TestFlight 2.0.10.3–2.0.10.5.
    case historicalB9a6768e = "SubstrateHistorical_b9a6768e87baa040"
    /// TestFlight 2.0.10.6–2.0.10.8.
    case historical71d5bd5d = "SubstrateHistorical_71d5bd5ded4db12f"
    /// TestFlight 2.0.10.9.
    case historicalA2680a72 = "SubstrateHistorical_a2680a724929571f"
    /// TestFlight 2.0.10.10.
    case historical6082d96e = "SubstrateHistorical_6082d96e8929023c"
    /// App Store 2.0.10.
    case historical16812164 = "SubstrateHistorical_16812164d61dbeb4"
    /// App Store 2.0.12–2.0.16.
    case historical1607d3b0 = "SubstrateHistorical_1607d3b0b76a26fb"
    /// TestFlight 2.0.15.x and 2.0.1000.12.
    case historical467c422c = "SubstrateHistorical_467c422cbed3e413"
    /// TestFlight 2.0.1000.13.
    case historicalE37c8808 = "SubstrateHistorical_e37c88089f0ec8a3"
    /// App Store 2.1.0–2.1.1.
    case historical46a317e0 = "SubstrateHistorical_46a317e0e5d34fa7"
    /// TestFlight 2.0.1000.14–2.0.1000.15.
    case historical6a9e0bb5 = "SubstrateHistorical_6a9e0bb518359972"
    /// App Store 2.2.0.
    case historical858c2b99 = "SubstrateHistorical_858c2b993253d609"
    /// TestFlight 2.2.0.4.
    case historical7d0188e7 = "SubstrateHistorical_7d0188e7cd13bedc"
    /// App Store 2.2.1.
    case historical829b48f2 = "SubstrateHistorical_829b48f2aaeaa058"
    /// TestFlight 2.0.1000.16.
    case historicalB80d247b = "SubstrateHistorical_b80d247b980d5efd"
    /// TestFlight 2.0.1000.18–2.0.1000.19.
    case historicalF2c90835 = "SubstrateHistorical_f2c90835e0c0cf24"
    /// App Store 2.4.1–2.4.3 and 2.4.6.
    case historical8dbf44e2 = "SubstrateHistorical_8dbf44e2f59b814a"
    /// App Store 2.4.4–2.4.5 and 3.0.1–3.1.1.
    case historical40fac78f = "SubstrateHistorical_40fac78f488eef8e"
    /// Development build 97910eee7 (2023-11-02).
    case historicalF41928b6 = "SubstrateHistorical_f41928b60f59b412"
    /// Development build e8c56c3fc (2023-11-10).
    case historicalB2974779 = "SubstrateHistorical_b297477951df254c"
    /// Development build 60c2a57f4 (2023-11-10).
    case historical038ca011 = "SubstrateHistorical_038ca011be713713"
    /// App Store 3.2.1 and 3.2.4.
    case historical32ac3b4f = "SubstrateHistorical_32ac3b4f6e7c6023"
    /// App Store 3.2.2–3.5.3.
    case historicalD484c09e = "SubstrateHistorical_d484c09eddea88ca"
    /// Development build b78bfde42 (2024-05-03).
    case historical4f4d570f = "SubstrateHistorical_4f4d570ff919c021"
    /// App Store 3.6.0.
    case historical02d51fe4 = "SubstrateHistorical_02d51fe4d9ec39aa"
    /// TestFlight 3.6.1.1–3.6.1.2.
    case historicalE65bafe1 = "SubstrateHistorical_e65bafe1d9757c47"
    /// Development build 133c581b7 (2024-08-08).
    case historical621ce0ac = "SubstrateHistorical_621ce0ac92c09ceb"
    /// Development build b2342dc6c (2024-08-22).
    case historical497f2e4a = "SubstrateHistorical_497f2e4a5aaef4ce"
    /// Development build 9a14307f6 (2024-08-23).
    case historical3d1e762d = "SubstrateHistorical_3d1e762d3131e9a4"
    /// Development build 8d094ae26 (2024-08-26).
    case historicalD56a5277 = "SubstrateHistorical_d56a527740e8c53f"
    /// Development build 16ed04073 (2024-08-29).
    case historicalCa676bc0 = "SubstrateHistorical_ca676bc0fe523c61"
    /// Development build 8691e5c70 (2024-08-30).
    case historical2275e388 = "SubstrateHistorical_2275e38844008174"
    /// Private App Store 4.0.1 (and private 5.0.0).
    case historical201c4116 = "SubstrateHistorical_201c41162d1b1604"
    /// Public App Store 4.0.2 and private App Store 4.0.4.
    case historical186efaed = "SubstrateHistorical_186efaedb554f36c"

    /// Lossless union of the modernized v8 and both public App Store schemas.
    case version10 = "SubstrateDataModel_v10"

    static let historicalModelDirectory = "HistoricalStoreModels"

    private static let historicalResourcePrefix = "SubstrateHistorical_"

    static var current: SubstrateStorageVersion {
        // Explicit, so that declaring a case after version10 can never move
        // the migration target.
        .version10
    }

    // One flat table of hops, so every landing is reviewable in one place.
    // swiftlint:disable:next cyclomatic_complexity function_body_length
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
        case .historical27378408,
             .historicalD7130246,
             .historical021514c3,
             .historical6ca82510,
             .historical5cffa3d6:
            return .version1
        case .historicalDdb3684b,
             .historicalF83c370e,
             .historical244dfde3,
             .historical92b1571a,
             .historicalB9a6768e,
             .historical71d5bd5d,
             .historicalA2680a72,
             .historical6082d96e,
             .historical16812164,
             .historical1607d3b0,
             .historical467c422c,
             .historicalE37c8808,
             .historical46a317e0,
             .historical6a9e0bb5,
             .historical858c2b99,
             .historical7d0188e7,
             .historical829b48f2:
            return .version2
        case .historicalB80d247b:
            return .version3
        case .historicalF2c90835:
            return .version4
        case .historical8dbf44e2,
             .historical40fac78f,
             .historicalF41928b6,
             .historicalB2974779,
             .historical038ca011,
             .historical32ac3b4f,
             .historicalD484c09e,
             .historical4f4d570f,
             .historical02d51fe4,
             .historicalE65bafe1:
            return .version5
        case .historical621ce0ac,
             .historical497f2e4a,
             .historical3d1e762d,
             .historicalD56a5277,
             .historicalCa676bc0,
             .historical2275e388,
             .historical201c4116,
             .historical186efaed:
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
            return isHistoricalResource
        }
    }

    /// Shipped in the app's `HistoricalStoreModels` folder rather than in the
    /// lineage model directory.
    var isHistoricalResource: Bool {
        rawValue.hasPrefix(Self.historicalResourcePrefix)
    }

    var requiresStartupGraphBounds: Bool {
        switch self {
        case .version8,
             .legacyPublicVersion8,
             .legacyPublicVersion9,
             .version10:
            return true
        // Historical v8 schemas that land directly on v10 with the whole
        // startup graph. The earliest v8 development models predate
        // CDPriceData and are bounded once they have been staged as v10.
        case .historical497f2e4a,
             .historicalD56a5277,
             .historicalCa676bc0,
             .historical2275e388,
             .historical201c4116,
             .historical186efaed:
            return true
        default:
            return false
        }
    }

    /// The reviewed cache-only entities and `Entity.property` names that the
    /// inferred mapping from a historical model to its landing model drops.
    /// The migrator fails closed when the real drop set differs in any way.
    var historicalAllowedDrops: (entities: Set<String>, attributes: Set<String>) {
        switch self {
        case .historical27378408, .historicalD7130246:
            // 1.7 removed the whole store instead of keeping amounts.
            return ([], ["CDTransactionHistoryItem.amount"])
        case .historical5cffa3d6:
            // Test entity shipped by 2.0.4.
            return (["CDMockEntity"], [])
        case .historicalF83c370e:
            return ([], ["CDChain.unused"])
        case .historicalB9a6768e,
             .historical71d5bd5d,
             .historicalA2680a72,
             .historical16812164:
            return ([], ["CDAsset.type"])
        case .historical6082d96e:
            return ([], ["CDAsset.accountInfo", "CDAsset.type"])
        case .historical8dbf44e2,
             .historical40fac78f,
             .historicalB2974779,
             .historical038ca011,
             .historical32ac3b4f,
             .historicalD484c09e:
            // JSON provider cache.
            return (["CDSingleValue"], [])
        case .historicalF41928b6:
            return (["CDSingleValue"], ["CDChainXcmConfig.bridgeParachainId"])
        case .historical621ce0ac, .historical3d1e762d:
            // Price cache, refreshed from the price providers.
            return ([], ["CDAsset.fiatDayChange", "CDAsset.price"])
        default:
            return ([], [])
        }
    }

    /// Values, keyed by `Entity.attribute`, for mandatory landing attributes
    /// that a historical model does not have at all. The inferred mapping
    /// would leave them empty and fail.
    var historicalRequiredConstants: [String: String] {
        switch self {
        case .historical27378408, .historicalD7130246:
            // The call path 1.7 wrote for local transfers.
            return [
                "CDTransactionHistoryItem.callName": "transfer",
                "CDTransactionHistoryItem.moduleName": "Balances"
            ]
        case .historical3d1e762d, .historicalD56a5277, .historicalCa676bc0:
            // The first TON Connect development builds stored no app name.
            return ["CDTonConnectedApp.name": ""]
        default:
            return [:]
        }
    }

    func modelURL(
        in bundle: Bundle,
        modelDirectory: String
    ) -> URL? {
        let subdirectory: String?
        if isHistoricalResource {
            subdirectory = Self.historicalModelDirectory
        } else {
            subdirectory = isCompatibilityResource ? nil : modelDirectory
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
