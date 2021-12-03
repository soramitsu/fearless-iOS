import Foundation
import Kingfisher

struct ChainAccountBalanceCellViewModel {
    let asset: AssetModel
    let chainName: String?
    let assetInfo: AssetBalanceDisplayInfo?
    let imageViewModel: RemoteImageViewModel?
    let balanceString: String?
    let priceAttributedString: NSAttributedString?
    let totalAmountString: String?
}
