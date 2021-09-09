import Foundation

struct CoingeckoPriceData: Codable, Equatable {
    var assetPriceList: [PriceData]

    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        var intValue: Int?

        init?(intValue _: Int) {
            nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)

        assetPriceList = try container.allKeys.map { key in
            try container.decode(
                PriceData.self,
                forKey: DynamicCodingKeys(stringValue: key.stringValue)!
            )
        }
    }

    static func == (lhs: CoingeckoPriceData, rhs: CoingeckoPriceData) -> Bool {
        lhs.assetPriceList == rhs.assetPriceList
    }
}

struct PriceData: Codable, Equatable {
    let price: String
    let usdDayChange: Decimal?

    enum CodingKeys: String, CodingKey {
        case price = "usd"
        case usdDayChange = "usd_24h_change"
    }
}
