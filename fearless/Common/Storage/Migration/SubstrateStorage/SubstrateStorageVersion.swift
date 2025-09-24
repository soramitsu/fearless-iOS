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
            return nil
        }
    }
}
