import Foundation

enum SubstrateStorageVersion: String, CaseIterable {
    case version1 = "SubstrateDataModel"
    case version2 = "SubstrateDataModel_v2"
    case version3 = "SubstrateDataModel_v3"
    case version4 = "SubstrateDataModel_v4"

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
            return nil
        }
    }
}
