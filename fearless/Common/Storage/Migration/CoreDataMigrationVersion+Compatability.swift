import Foundation
import CoreData

extension CoreDataMigrationVersion {
    // MARK: - Compatible

    static func compatibleVersionForStoreMetadata(_ metadata: [String: Any]) -> CoreDataMigrationVersion? {
        let compatibleVersion = CoreDataMigrationVersion.allCases.first {
            let model = NSManagedObjectModel.managedObjectModel(forResource: $0.rawValue)

            return model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }

        return compatibleVersion
    }
}
