import Foundation
import FearlessUtils

protocol StakingMainViewModelProtocol {
    var address: String { get }
}

struct StakingMainViewModel: StakingMainViewModelProtocol {
    let address: String
}
