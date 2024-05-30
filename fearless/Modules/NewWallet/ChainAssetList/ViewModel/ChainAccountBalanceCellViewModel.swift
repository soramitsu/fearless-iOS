import Foundation
import Kingfisher
import SSFModels

struct ChainAccountBalanceCellViewModel: Hashable {
    let assetContainsChainAssets: [ChainAsset]
    let chainIconViewViewModel: ChainCollectionViewModel
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
    let locale: Locale
    let hideButtonIsVisible: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(chainAsset.chainAssetId)
        hasher.combine(balanceString)
        hasher.combine(isColdBoot)
    }
}

extension ChainAccountBalanceCellViewModel: Equatable {
    static func == (lhs: ChainAccountBalanceCellViewModel, rhs: ChainAccountBalanceCellViewModel) -> Bool {
        lhs.assetContainsChainAssets == rhs.assetContainsChainAssets &&
            lhs.chainIconViewViewModel == rhs.chainIconViewViewModel &&
            lhs.chainAsset == rhs.chainAsset &&
            lhs.assetName == rhs.assetName &&
            lhs.assetInfo == rhs.assetInfo &&
            lhs.balanceString == rhs.balanceString &&
            lhs.priceAttributedString == rhs.priceAttributedString &&
            lhs.totalAmountString == rhs.totalAmountString &&
            lhs.options == rhs.options &&
            lhs.priceDataWasUpdated == rhs.priceDataWasUpdated
    }
}
