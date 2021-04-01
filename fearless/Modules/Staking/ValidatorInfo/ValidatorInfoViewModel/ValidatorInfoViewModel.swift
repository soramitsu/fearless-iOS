import UIKit
import FearlessUtils

protocol ValidatorInfoAccountViewModelProtocol {
    var name: String? { get }
    var address: String { get }
    var icon: UIImage? { get }
}

struct ValidatorInfoAccountViewModel: ValidatorInfoAccountViewModelProtocol {
    let name: String?
    let address: String
    let icon: UIImage?
}
