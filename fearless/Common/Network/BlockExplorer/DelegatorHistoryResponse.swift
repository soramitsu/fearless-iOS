import Foundation

protocol DelegatorHistoryResponse {
    func history(for address: String) -> [DelegatorHistoryItem]
}
