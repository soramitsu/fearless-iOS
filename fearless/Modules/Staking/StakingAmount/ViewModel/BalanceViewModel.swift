import Foundation

protocol BalanceViewModelProtocol {
    var amount: String { get }
    var price: String? { get }
}

struct BalanceViewModel: BalanceViewModelProtocol {
    let amount: String
    let price: String?
}
