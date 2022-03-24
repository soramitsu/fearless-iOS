import Foundation

protocol ManageAssetsTableViewCellModelDelegate: AnyObject {
    func switchAssetEnabledState(asset: AssetModel)
}

class ManageAssetsTableViewCellModel {
    let chain: ChainModel
    let asset: AssetModel
    let assetName: String?
    let assetInfo: AssetBalanceDisplayInfo?
    let imageViewModel: RemoteImageViewModel?
    let balanceString: String?
    let options: [ChainOptionsViewModel]?

    weak var delegate: ManageAssetsTableViewCellModelDelegate?

    internal init(
        chain: ChainModel,
        asset: AssetModel,
        assetName: String?,
        assetInfo: AssetBalanceDisplayInfo?,
        imageViewModel: RemoteImageViewModel?,
        balanceString: String?,
        options: [ChainOptionsViewModel]?
    ) {
        self.chain = chain
        self.asset = asset
        self.assetName = assetName
        self.assetInfo = assetInfo
        self.imageViewModel = imageViewModel
        self.balanceString = balanceString
        self.options = options
    }
}

extension ManageAssetsTableViewCellModel: ManageAssetsTableViewCellDelegate {
    func assetEnabledSwitcherValueChanged() {
        delegate?.switchAssetEnabledState(asset: asset)
    }
}
