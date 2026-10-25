import Foundation
import UIKit
import SSFModels

struct AssetManagementViewModel {
    var list: [AssetManagementTableSection]
    let filterButtonTitle: String
    let addAssetButtonIsHidden: Bool
    var dispayedChainAssets: [ChainAsset]
    var allChainAssets: [ChainAsset] = []
    var networkFilter: NetworkManagmentFilter?
    var search: String?
    var revision = UUID()
    var visibilityFilter: ManageAssetsFilter = .all
    var canResetOrder = false

    func filtered(by filter: ManageAssetsFilter) -> AssetManagementViewModel {
        var result = self
        result.visibilityFilter = filter
        result.list = list.compactMap { section in
            var section = section
            section.cells = section.cells.filter(filter.accepts)
            return section.cells.isEmpty ? nil : section
        }
        result.dispayedChainAssets = result.list.flatMap(\.cells).map(\.chainAsset)
        return result
    }
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
    var id: String = ""
    var visibilityMembers: [ChainAsset] = []
    var groupVisibility: ManageGroupVisibility = .off
}

struct AssetManagementTableCellViewModel {
    let chainAsset: ChainAsset
    let assetImage: ImageViewModelProtocol?
    let assetName: String
    let chainName: String
    var balance: BalanceViewModelProtocol
    var decimalPrice: Decimal
    var hidden: Bool
    var hasGroup: Bool
    var isLoadingBalance: Bool
    var preference: AssetPreference = .auto
    var preferenceCaption: String = ""
    var amount: Decimal = .zero
    var valueRole: PortfolioValueRole = .unpriced
}
