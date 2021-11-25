import Foundation
import Kingfisher

struct ChainAccountBalanceCellViewModel {
    let chainName: String?
    let assetInfo: AssetBalanceDisplayInfo?
    let balanceString: String?
    let priceAttributedString: NSAttributedString?
    let totalAmountString: String?
}
