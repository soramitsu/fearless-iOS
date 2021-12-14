import Foundation
import Kingfisher

struct ChainAccountBalanceCellViewModel {
    let asset: AssetModel
    let assetName: String?
    let assetInfo: AssetBalanceDisplayInfo?
    let imageViewModel: RemoteImageViewModel?
    let balanceString: String?
    let priceAttributedString: NSAttributedString?
    let totalAmountString: String?
    let options: [ChainOptionsViewModel]?
}
