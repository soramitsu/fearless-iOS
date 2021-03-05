import Foundation

protocol EraStakingViewModelProtocol {
    var totalStakeAmount: String { get }
    var totalStakePrice: String? { get }
    var minimalStakeAmount: String { get }
    var minimalStakePrice: String? { get }
    var activeNominations: String { get }
    var lockupPeriod: String { get }
}
