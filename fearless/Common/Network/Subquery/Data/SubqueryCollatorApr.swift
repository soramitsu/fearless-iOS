import Foundation

struct SubqueryCollatorAprResponse: Decodable {
    struct HistoryElements: Decodable {
        let nodes: [SubqueryCollatorAprInfo]
    }

    let collatorRounds: HistoryElements
}

struct SubqueryCollatorAprInfo: Decodable, Equatable, CollatorAprInfoProtocol {
    var collatorId: String
    var apr: Double
}

extension SubqueryCollatorAprResponse: CollatorAprResponse {
    var collatorAprInfos: [CollatorAprInfoProtocol] {
        collatorRounds.nodes
    }
}
