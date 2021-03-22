import Foundation
import SoraFoundation

protocol EraStakingInfoViewModelProtocol {
    var totalStake: BalanceViewModelProtocol? { get }
    var minimalStake: BalanceViewModelProtocol? { get }
    var activeNominators: String? { get }
}

struct EraStakingInfoViewModel: EraStakingInfoViewModelProtocol {
    let totalStake: BalanceViewModelProtocol?
    let minimalStake: BalanceViewModelProtocol?
    let activeNominators: String?
}
