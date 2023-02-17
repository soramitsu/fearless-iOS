import Foundation
import BigInt

struct SubsquidDelegatorHistoryData: Decodable {
    let historyElements: [SubsquidDelegatorHistoryItem]
}

struct SubsquidDelegatorHistoryItem: Decodable, DelegatorHistoryItem {
    let id: String
    let type: SubqueryDelegationAction
    let timestamp: String
    let blockNumber: Int
    let amount: BigUInt
}

extension SubsquidDelegatorHistoryData: DelegatorHistoryResponse {
    func history(for _: String) -> [DelegatorHistoryItem] {
        historyElements
    }
}
