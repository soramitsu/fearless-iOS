import Foundation
import RobinHood
import CoreData
import SSFModels

enum PriceDataMapperError: Error {
    case missedRequiredFields
    case notSupported
}

final class PriceDataModelMapper: CoreDataMapperProtocol {
    typealias DataProviderModel = PriceData
    typealias CoreDataEntity = CDPriceData

    func transform(entity: CDPriceData) throws -> PriceData {
        guard let currencyId = entity.currencyId,
              let priceId = entity.priceId,
              let price = entity.price else {
            throw PriceDataMapperError.missedRequiredFields
        }
        return PriceData(
            currencyId: currencyId,
            priceId: priceId,
            price: price,
            fiatDayChange: Decimal(string: entity.fiatDayByChange ?? ""),
            coingeckoPriceId: entity.coingeckoPriceId
        )
    }

    func populate(entity: CDPriceData, from model: PriceData, using _: NSManagedObjectContext) throws {
        entity.currencyId = model.currencyId
        entity.priceId = model.priceId
        entity.price = model.price
        entity.fiatDayByChange = String("\(model.fiatDayChange)")
        entity.coingeckoPriceId = model.coingeckoPriceId
    }

    var entityIdentifierFieldName: String { "priceId" }
}
