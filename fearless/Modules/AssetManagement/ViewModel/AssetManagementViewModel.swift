import Foundation
import UIKit
import SSFModels

struct AssetManagementViewModel {
    var list: [AssetManagementTableSection]
    let filterButtonTitle: String
    let addAssetButtonIsHidden: Bool
    let dispayedChainAssets: [ChainAsset]
}

struct AssetManagementTableSection {
    let hasView: Bool
    let assetImage: ImageViewModelProtocol?
    let assetName: String?
    let assetCount: String?
    var isExpanded: Bool
    var cells: [AssetManagementTableCellViewModel]
    var isAllDisabled: Bool
    let totalBalance: Decimal
    let totalFiatBalance: Decimal
    let rank: UInt16
}

struct AssetManagementTableCellViewModel {
    let chainAsset: ChainAsset
    let assetImage: ImageViewModelProtocol?
    let assetName: String
    let chainName: String
    var balance: BalanceViewModelProtocol
    var decimalPrice: Decimal
    var hidden: Bool
    let hasGroup: Bool
    var isLoadingBalance: Bool
}
