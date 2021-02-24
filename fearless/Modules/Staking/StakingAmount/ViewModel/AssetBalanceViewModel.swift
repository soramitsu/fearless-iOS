import UIKit

protocol AssetBalanceViewModelProtocol {
    var icon: UIImage? { get }
    var symbol: String { get }
    var balance: String? { get }
    var price: String? { get }
}

struct AssetBalanceViewModel: AssetBalanceViewModelProtocol {
    let icon: UIImage?
    let symbol: String
    let balance: String?
    let price: String?
}
