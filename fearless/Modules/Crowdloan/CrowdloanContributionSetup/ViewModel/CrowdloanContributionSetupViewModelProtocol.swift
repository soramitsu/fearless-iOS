import Foundation
import CommonWallet

protocol CrowdloanContributionSetupViewModelProtocol {
    var title: String { get set }
    var leasingPeriod: String { get set }
    var leasingCompletionDate: String { get set }
    var raisedProgress: String { get set }
    var raisedPercentage: String { get set }
    var remainedTime: String { get set }
    var learnMore: LearnMoreViewModel? { get set }
    var assetBalance: AssetBalanceViewModelProtocol? { get set }
    var fee: BalanceViewModelProtocol? { get set }
    var estimatedReward: String? { get set }
    var bonus: String? { get set }
    var amountInput: AmountInputViewModelProtocol { get set }
    var previousContribution: String? { get set }
}
