import Foundation

struct ManageAssetsTableViewCellModel {
    let chain: ChainModel
    let asset: AssetModel
    let assetName: String?
    let assetInfo: AssetBalanceDisplayInfo?
    let imageViewModel: RemoteImageViewModel?
    let balanceString: String?
    let options: [ChainOptionsViewModel]?
}
