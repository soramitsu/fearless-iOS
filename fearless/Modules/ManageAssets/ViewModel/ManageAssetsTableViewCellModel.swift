import Foundation

protocol ManageAssetsTableViewCellModelDelegate: AnyObject {
    func switchAssetEnabledState(asset: ChainAsset)
    func showMissingAccountOptions(chainAsset: ChainAsset)
}

class ManageAssetsTableViewCellModel {
    let chainAsset: ChainAsset
    let assetName: String?
    let assetInfo: AssetBalanceDisplayInfo?
    let imageViewModel: RemoteImageViewModel?
    let balanceString: String?
    let options: [ChainOptionsViewModel]?
    let assetEnabled: Bool
    let accountMissing: Bool
    let chainUnused: Bool
    let locale: Locale?

    weak var delegate: ManageAssetsTableViewCellModelDelegate?

    internal init(
        chainAsset: ChainAsset,
        assetName: String?,
        assetInfo: AssetBalanceDisplayInfo?,
        imageViewModel: RemoteImageViewModel?,
        balanceString: String?,
        options: [ChainOptionsViewModel]?,
        assetEnabled: Bool,
        accountMissing: Bool,
        chainUnused: Bool,
        locale: Locale?
    ) {
        self.chainAsset = chainAsset
        self.assetName = assetName
        self.assetInfo = assetInfo
        self.imageViewModel = imageViewModel
        self.balanceString = balanceString
        self.options = options
        self.assetEnabled = assetEnabled
        self.accountMissing = accountMissing
        self.chainUnused = chainUnused
        self.locale = locale
    }

    var cellInactive: Bool {
        !chainAsset.chain.isSupported || accountMissing
    }
}

extension ManageAssetsTableViewCellModel: ManageAssetsTableViewCellDelegate {
    func assetEnabledSwitcherValueChanged() {
        delegate?.switchAssetEnabledState(asset: chainAsset)
    }

    func addAccountButtonClicked() {
        delegate?.showMissingAccountOptions(chainAsset: chainAsset)
    }
}
