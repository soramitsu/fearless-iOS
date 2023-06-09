import Foundation
import RobinHood
import CoreData
import IrohaCrypto
import SSFModels

enum ChainNodeMapperError: Error {
    case missedRequiredFields
    case notSupported
}

final class ChainNodeModelMapper: CoreDataMapperProtocol {
    func transform(entity: CDChainNode) throws -> ChainNodeModel {
        guard let url = entity.url,
              let name = entity.name else {
            throw ChainNodeMapperError.missedRequiredFields
        }

        return ChainNodeModel(
            url: url,
            name: name,
            apikey: nil
        )
    }

    func populate(entity: CDChainNode, from model: ChainNodeModel, using _: NSManagedObjectContext) throws {
        entity.name = model.name
        entity.url = model.url
        entity.apiKeyName = model.apikey?.keyName
        entity.apiQueryName = model.apikey?.queryName
    }

    var entityIdentifierFieldName: String { "url.absoluteString" }

    typealias DataProviderModel = ChainNodeModel

    typealias CoreDataEntity = CDChainNode
}
