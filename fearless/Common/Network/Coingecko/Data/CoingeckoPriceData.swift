import Foundation

struct CoingeckoPriceData: Decodable {
    var assetPriceList: [CoingeckoAssetPriceData]

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

        var tempArray: [CoingeckoAssetPriceData] = []

        for key in container.allKeys {
            let decodedObject = try container.decode(
                CoingeckoAssetPriceData.self,
                forKey: DynamicCodingKeys(stringValue: key.stringValue)!
            )
            tempArray.append(decodedObject)
        }

        assetPriceList = tempArray
    }
}

struct CoingeckoAssetPriceData: Decodable {
    let usd: Decimal
    let usdDayChange: Decimal?

    enum CodingKeys: String, CodingKey {
        case usd
        case usdDayChange = "usd_24h_change"
    }
}
