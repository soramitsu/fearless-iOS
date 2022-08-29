import Foundation
import Kingfisher

struct ChainAccountBalanceCellViewModel {
    let assetContainsChainAssets: [ChainAsset]
    let chainAsset: ChainAsset
    let assetName: String?
    let assetInfo: AssetBalanceDisplayInfo?
    let imageViewModel: RemoteImageViewModel?
    let balanceString: ShimmeredLabelState
    let priceAttributedString: ShimmeredLabelState
    let totalAmountString: ShimmeredLabelState
    let options: [ChainOptionsViewModel]?
    var isColdBoot: Bool
    var priceDataWasUpdated: Bool
    let isNetworkIssues: Bool
}
