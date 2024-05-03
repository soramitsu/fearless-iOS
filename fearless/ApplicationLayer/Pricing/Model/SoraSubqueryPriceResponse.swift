import Foundation
import SSFUtils

struct SoraSubqueryPriceResponse: Decodable {
    let entities: SoraSubqueryPricePage
}

struct SoraSubqueryPricePage: Decodable {
    let nodes: [SoraSubqueryPrice]
    let pageInfo: SubqueryPageInfo
}

struct SoraSubqueryPrice: Decodable {
    let id: String
    let priceUsd: String?
    let priceChangeDay: Decimal?
}
