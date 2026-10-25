import Foundation

public struct PriceData: Codable, Equatable {
    public let currencyId: String
    public let priceId: String
    public let price: String
    public let fiatDayChange: Decimal?
    public let coingeckoPriceId: String?

    public init(
        currencyId: String,
        priceId: String,
        price: String,
        fiatDayChange: Decimal?,
        coingeckoPriceId: String?
    ) {
        self.currencyId = currencyId
        self.priceId = priceId
        self.price = price
        self.fiatDayChange = fiatDayChange
        self.coingeckoPriceId = coingeckoPriceId
    }

    public func replaceFiatDayChange(fiatDayChange: Decimal?) -> PriceData {
        PriceData(
            currencyId: currencyId,
            priceId: priceId,
            price: price,
            fiatDayChange: fiatDayChange,
            coingeckoPriceId: coingeckoPriceId
        )
    }
}
