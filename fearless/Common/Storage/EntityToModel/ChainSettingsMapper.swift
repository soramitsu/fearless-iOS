import Foundation
import RobinHood
import CoreData
import IrohaCrypto
#if canImport(SSFAccountManagmentStorage)
    import SSFAccountManagmentStorage
#endif

final class ChainSettingsMapper: CoreDataMapperProtocol {
    var entityIdentifierFieldName: String { "chainId" }

    typealias DataProviderModel = ChainSettings
    typealias CoreDataEntity = CDChainSettings

    func transform(entity: CDChainSettings) throws -> ChainSettings {
        guard let chainId = entity.chainId else {
            throw ChainNodeMapperError.missedRequiredFields
        }

        let autobalanced = (entity.value(forKey: "autobalanced") as? Bool) ?? false
        let issueMuted = (entity.value(forKey: "issueMuted") as? Bool) ?? false

        return ChainSettings(
            chainId: chainId,
            autobalanced: autobalanced,
            issueMuted: issueMuted
        )
    }

    func populate(entity: CDChainSettings, from model: ChainSettings, using _: NSManagedObjectContext) throws {
        entity.chainId = model.chainId
        entity.setValue(model.autobalanced, forKey: "autobalanced")
        entity.setValue(model.issueMuted, forKey: "issueMuted")
    }
}
