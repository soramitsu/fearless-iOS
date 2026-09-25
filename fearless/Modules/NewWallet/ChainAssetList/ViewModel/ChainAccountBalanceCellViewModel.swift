import Foundation
import Kingfisher
import SSFModels

struct ChainAccountBalanceCellViewModel: Hashable {
    let assetContainsChainAssets: [ChainAsset]
    let chainIconViewViewModel: ChainCollectionViewModel
    let chainAsset: ChainAsset
    let metadataTrust: AssetMetadataTrustInfo
    let assetName: String?
    let assetInfo: AssetBalanceDisplayInfo?
    let imageViewModel: RemoteImageViewModel?
    let balanceString: ShimmeredLabelState
    let priceAttributedString: ShimmeredLabelState
    let totalAmountString: ShimmeredLabelState
    let options: [ChainOptionsViewModel]?
    var isColdBoot: Bool
    let locale: Locale
    let hideButtonIsVisible: Bool
    let swipeActionsEnabled: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(chainAsset.chainAssetId)
        hasher.combine(balanceString)
        hasher.combine(isColdBoot)
        hasher.combine(swipeActionsEnabled)
    }
}

extension ChainAccountBalanceCellViewModel: Equatable {
    static func == (lhs: ChainAccountBalanceCellViewModel, rhs: ChainAccountBalanceCellViewModel) -> Bool {
        lhs.assetContainsChainAssets == rhs.assetContainsChainAssets &&
            lhs.chainIconViewViewModel == rhs.chainIconViewViewModel &&
            lhs.chainAsset == rhs.chainAsset &&
            lhs.metadataTrust == rhs.metadataTrust &&
            lhs.assetName == rhs.assetName &&
            lhs.assetInfo == rhs.assetInfo &&
            lhs.balanceString == rhs.balanceString &&
            lhs.priceAttributedString == rhs.priceAttributedString &&
            lhs.totalAmountString == rhs.totalAmountString &&
            lhs.options == rhs.options &&
            lhs.swipeActionsEnabled == rhs.swipeActionsEnabled
    }
}
