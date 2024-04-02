import Foundation

struct ChainAssetListViewModel {
    let cells: [ChainAccountBalanceCellViewModel]
    let emptyStateIsActive: Bool
    let isSearch: Bool
    let shouldRunManageAssetAnimate: Bool
}
