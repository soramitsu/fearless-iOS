import Foundation
import SoraFoundation

protocol NetworkStakingInfoViewModelProtocol {
    var totalStake: BalanceViewModelProtocol? { get }
    var minimalStake: BalanceViewModelProtocol? { get }
    var activeNominators: String? { get }
    var lockUpPeriod: String? { get }
    var viewIsCollapsed: Bool { get }
}

struct NetworkStakingInfoViewModel: NetworkStakingInfoViewModelProtocol {
    let totalStake: BalanceViewModelProtocol?
    let minimalStake: BalanceViewModelProtocol?
    let activeNominators: String?
    let lockUpPeriod: String?
    let viewIsCollapsed: Bool
}
