import Foundation
import Kingfisher

struct ChainAccountBalanceCellViewModel {
    let chain: ChainModel
    let asset: AssetModel
    let assetName: String?
    let assetInfo: AssetBalanceDisplayInfo?
    let imageViewModel: RemoteImageViewModel?
    let balanceString: ShimmeredLabelState
    let priceAttributedString: ShimmeredLabelState
    let totalAmountString: ShimmeredLabelState
    let options: [ChainOptionsViewModel]?
    var isColdBoot: Bool
    var priceDataWasUpdated: Bool
}
