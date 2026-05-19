import Foundation
import RobinHood
import CoreData
import SSFModels

enum PriceDataMapperError: Error {
    case missedRequiredFields
    case notSupported
}

extension PriceData: RobinHood.Identifiable {
    public var identifier: String { "\(currencyId):\(priceId)" }
}

final class PriceDataModelMapper: CoreDataMapperProtocol {
    typealias DataProviderModel = PriceData
    typealias CoreDataEntity = NSManagedObject

    func transform(entity: NSManagedObject) throws -> PriceData {
        guard
            let currencyId = entity.value(forKey: "currencyId") as? String,
            let priceId = entity.value(forKey: "priceId") as? String
        else {
            throw PriceDataMapperError.missedRequiredFields
        }
        let priceString: String? = {
            if let d = entity.value(forKey: "price") as? Decimal {
                return NSDecimalNumber(decimal: d).stringValue
            }
            if let n = entity.value(forKey: "price") as? NSDecimalNumber {
                return n.stringValue
            }
            if let s = entity.value(forKey: "price") as? String { return s }
            return nil
        }()
        guard let price = priceString else { throw PriceDataMapperError.missedRequiredFields }

        let fiatDayStr = entity.value(forKey: "fiatDayByChange") as? String
        let coingeckoPriceId = entity.value(forKey: "coingeckoPriceId") as? String

        return PriceData(
            currencyId: currencyId,
            priceId: priceId,
            price: price,
            fiatDayChange: Decimal(string: fiatDayStr ?? ""),
            coingeckoPriceId: coingeckoPriceId
        )
    }

    func populate(entity: NSManagedObject, from model: PriceData, using _: NSManagedObjectContext) throws {
        entity.setValue(model.currencyId, forKey: "currencyId")
        entity.setValue(model.priceId, forKey: "priceId")
        entity.setValue(model.price, forKey: "price")
        entity.setValue(String("\(model.fiatDayChange)"), forKey: "fiatDayByChange")
        entity.setValue(model.coingeckoPriceId, forKey: "coingeckoPriceId")
    }

    var entityIdentifierFieldName: String { "priceId" }
}
