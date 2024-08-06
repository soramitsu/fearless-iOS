import Foundation
import RobinHood
import CoreData
import IrohaCrypto
import SSFAccountManagmentStorage

final class ChainSettingsMapper: CoreDataMapperProtocol {
    var entityIdentifierFieldName: String { "chainId" }

    typealias DataProviderModel = ChainSettings
    typealias CoreDataEntity = CDChainSettings

    func transform(entity: CDChainSettings) throws -> ChainSettings {
        guard let chainId = entity.chainId else {
            throw ChainNodeMapperError.missedRequiredFields
        }

        return ChainSettings(
            chainId: chainId,
            autobalanced: entity.autobalanced,
            issueMuted: entity.issueMuted
        )
    }

    func populate(entity: CDChainSettings, from model: ChainSettings, using _: NSManagedObjectContext) throws {
        entity.chainId = model.chainId
        entity.autobalanced = model.autobalanced
        entity.issueMuted = model.issueMuted
    }
}
