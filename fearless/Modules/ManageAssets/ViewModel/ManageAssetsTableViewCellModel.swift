import Foundation

protocol ManageAssetsTableViewCellModelDelegate: AnyObject {
    func switchAssetEnabledState(asset: ChainAsset)
}

class ManageAssetsTableViewCellModel {
    let chainAsset: ChainAsset
    let assetName: String?
    let assetInfo: AssetBalanceDisplayInfo?
    let imageViewModel: RemoteImageViewModel?
    let balanceString: String?
    let options: [ChainOptionsViewModel]?
    let assetEnabled: Bool

    weak var delegate: ManageAssetsTableViewCellModelDelegate?

    internal init(
        chainAsset: ChainAsset,
        assetName: String?,
        assetInfo: AssetBalanceDisplayInfo?,
        imageViewModel: RemoteImageViewModel?,
        balanceString: String?,
        options: [ChainOptionsViewModel]?,
        assetEnabled: Bool
    ) {
        self.chainAsset = chainAsset
        self.assetName = assetName
        self.assetInfo = assetInfo
        self.imageViewModel = imageViewModel
        self.balanceString = balanceString
        self.options = options
        self.assetEnabled = assetEnabled
    }
}

extension ManageAssetsTableViewCellModel: ManageAssetsTableViewCellDelegate {
    func assetEnabledSwitcherValueChanged() {
        delegate?.switchAssetEnabledState(asset: chainAsset)
    }
}
