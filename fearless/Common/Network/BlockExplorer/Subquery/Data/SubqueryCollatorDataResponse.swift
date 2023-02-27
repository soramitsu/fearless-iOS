import Foundation

struct SubqueryCollatorDataResponse: Decodable {
    struct HistoryElements: Decodable {
        let nodes: [SubqueryCollatorData]
    }

    let collatorRounds: HistoryElements
}

struct SubqueryCollatorData: Decodable, Equatable {
    let collatorId: String
    let apr: Double
}
