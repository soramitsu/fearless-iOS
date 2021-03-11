import UIKit
import FearlessUtils

protocol ValidatorInfoAccountViewModelProtocol {
    var name: String? { get }
    var address: String { get }
    var icon: UIImage? { get }
}

struct ValidatorInfoAccountViewModel: ValidatorInfoAccountViewModelProtocol {
    var name: String?
    var address: String
    var icon: UIImage?
}
