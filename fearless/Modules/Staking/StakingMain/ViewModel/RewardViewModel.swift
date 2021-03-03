import Foundation

protocol RewardViewModelProtocol {
    var amount: String { get }
    var price: String? { get }
    var increase: String? { get }
}

struct RewardViewModel: RewardViewModelProtocol {
    let amount: String
    let price: String?
    let increase: String?
}
