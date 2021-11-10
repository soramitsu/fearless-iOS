import Foundation
import CommonWallet

class CrowdloanContributionSetupViewModel: CrowdloanContributionSetupViewModelProtocol {
    var title: String
    var leasingPeriod: String
    var leasingCompletionDate: String
    var raisedProgress: String
    var raisedPercentage: String
    var remainedTime: String
    var learnMore: LearnMoreViewModel?
    var assetBalance: AssetBalanceViewModelProtocol?
    var fee: BalanceViewModelProtocol?
    var estimatedReward: String?
    var bonus: String?
    var amountInput: AmountInputViewModelProtocol

    init(
        title: String,
        leasingPeriod: String,
        leasingCompletionDate: String,
        raisedProgress: String,
        raisedPercentage: String,
        remainedTime: String,
        learnMore: LearnMoreViewModel?,
        assetBalance: AssetBalanceViewModelProtocol?,
        fee: BalanceViewModelProtocol?,
        estimatedReward: String?,
        bonus: String?,
        amountInput: AmountInputViewModelProtocol
    ) {
        self.title = title
        self.leasingPeriod = leasingPeriod
        self.leasingCompletionDate = leasingCompletionDate
        self.raisedProgress = raisedProgress
        self.raisedPercentage = raisedPercentage
        self.remainedTime = remainedTime
        self.learnMore = learnMore
        self.assetBalance = assetBalance
        self.fee = fee
        self.estimatedReward = estimatedReward
        self.bonus = bonus
        self.amountInput = amountInput
    }
}

class MoonbeamCrowdloanContributionSetupViewModel: CrowdloanContributionSetupViewModel {}

class AcalaCrowdloanContributionSetupViewModel: CrowdloanContributionSetupViewModel {
    enum ContributionType {
        case directDot
        case lcDot
    }

    var contributionType: ContributionType
    var isTermsAgreed: Bool

    init(
        title: String,
        leasingPeriod: String,
        leasingCompletionDate: String,
        raisedProgress: String,
        raisedPercentage: String,
        remainedTime: String,
        learnMore: LearnMoreViewModel?,
        assetBalance: AssetBalanceViewModelProtocol?,
        fee: BalanceViewModelProtocol?,
        estimatedReward: String?,
        bonus: String?,
        amountInput: AmountInputViewModelProtocol,
        contributionType: ContributionType,
        isTermsAgreed: Bool
    ) {
        self.contributionType = contributionType
        self.isTermsAgreed = isTermsAgreed

        super.init(
            title: title,
            leasingPeriod: leasingPeriod,
            leasingCompletionDate: leasingCompletionDate,
            raisedProgress: raisedProgress,
            raisedPercentage: raisedPercentage,
            remainedTime: remainedTime,
            learnMore: learnMore,
            assetBalance: assetBalance,
            fee: fee,
            estimatedReward: estimatedReward,
            bonus: bonus,
            amountInput: amountInput
        )
    }
}
