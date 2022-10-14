import Foundation

struct StakingPoolInfoViewModel {
    let indexTitle: String?
    let name: String?
    let state: String?
    let stakedAmountViewModel: BalanceViewModelProtocol?
    let membersCountTitle: String?
    let validatorsCountAttributedString: NSAttributedString?
    let depositorName: String?
    let rootName: String?
    let nominatorName: String?
    let stateTogglerName: String?
}
