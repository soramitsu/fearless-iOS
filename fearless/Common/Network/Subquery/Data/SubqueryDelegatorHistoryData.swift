import Foundation

struct SubqueryDelegatorHistoryData: Decodable {
    struct HistoryElements: Decodable {
        let nodes: [SubqueryDelegatorHistoryElement]
    }

    let delegators: HistoryElements
}
