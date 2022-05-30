import Foundation

struct ChainAccountBalanceListViewModel {
    let accountName: String?
    let balance: ShimmeredLabelState
    let accountViewModels: [ChainAccountBalanceCellViewModel]
    let ethAccountMissed: Bool
    let isColdBoot: Bool
}
