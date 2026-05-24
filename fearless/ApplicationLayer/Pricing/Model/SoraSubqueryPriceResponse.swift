import Foundation
import SSFUtils

struct SoraSubqueryPriceResponse: Decodable {
    let entities: SoraSubqueryPricePage
}

struct SoraSubqueryPricePage: Decodable {
    let nodes: [SoraSubqueryPrice]
    let pageInfo: SubqueryPageInfo

    enum CodingKeys: String, CodingKey {
        case nodes
        case edges
        case pageInfo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pageInfo = try container.decode(SubqueryPageInfo.self, forKey: .pageInfo)

        if let nodes = try container.decodeIfPresent([SoraSubqueryPrice].self, forKey: .nodes) {
            self.nodes = nodes
        } else {
            let edges = try container.decodeIfPresent([SoraSubqueryPriceEdge].self, forKey: .edges)
            nodes = edges?.map { $0.node } ?? []
        }
    }
}

struct SoraSubqueryPrice: Decodable {
    enum CodingKeys: String, CodingKey {
        case id
        case priceUsd = "priceUSD"
        case priceChangeDay
    }

    let id: String
    let priceUsd: String?
    let priceChangeDay: Decimal?
}

private struct SoraSubqueryPriceEdge: Decodable {
    let node: SoraSubqueryPrice
}
