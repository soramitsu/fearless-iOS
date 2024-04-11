import Foundation
import UIKit

struct AssetManagementViewModel {
    var list: [AssetManagementTableSection]
    let filterButtonTitle: String
    let addAssetButtonIsHidden: Bool
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
    let chainAssetId: String
    let assetImage: ImageViewModelProtocol?
    let assetName: String
    let chainName: String
    let balance: BalanceViewModelProtocol
    let decimalPrice: Decimal
    var hidden: Bool
    let hasGroup: Bool
}
