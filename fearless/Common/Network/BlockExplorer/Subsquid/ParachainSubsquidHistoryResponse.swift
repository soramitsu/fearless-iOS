import Foundation
import Web3
import SSFUtils

struct SubsquidDelegatorHistoryData: Decodable {
    let historyElements: [SubsquidDelegatorHistoryItem]
}

struct SubsquidDelegatorHistoryItem: Decodable, DelegatorHistoryItem {
    let id: String
    let type: SubqueryDelegationAction
    let timestamp: String
    let blockNumber: Int
    @StringCodable var amount: BigUInt
}

extension SubsquidDelegatorHistoryData: DelegatorHistoryResponse {
    func history(for _: String) -> [DelegatorHistoryItem] {
        historyElements
    }
}
