import Foundation
import SSFModels

protocol WalletAssetManagementHelper {
    func update(
        _ wallet: MetaAccountModel,
        with accountInfoResult: Result<AccountInfo?, Error>,
        chainAsset: ChainAsset
    ) -> MetaAccountModel
}

final class WalletAssetManagementHelperImpl: WalletAssetManagementHelper {
    func update(
        _ wallet: MetaAccountModel,
        with accountInfoResult: Result<AccountInfo?, Error>,
        chainAsset: ChainAsset
    ) -> MetaAccountModel {
        guard !wallet.assetsVisibility.contains(where: { $0.assetId == chainAsset.asset.id }) else {
            return wallet
        }
        switch accountInfoResult {
        case let .success(accountInfo):
            let updatedWallet = update(wallet, with: accountInfo, chainAsset: chainAsset)
            return updatedWallet
        case .failure:
            let hiddenAssetVisibility = AssetVisibility(assetId: chainAsset.asset.id, hidden: true)
            let updatedWallet = update(wallet, with: hiddenAssetVisibility)
            return updatedWallet
        }
    }

    // MARK: - Private methods

    private func update(
        _ wallet: MetaAccountModel,
        with accountInfo: AccountInfo?,
        chainAsset: ChainAsset
    ) -> MetaAccountModel {
        let isHidden = accountInfo?.zero() ?? true
        let assetVisibility = AssetVisibility(assetId: chainAsset.asset.id, hidden: isHidden)
        let updatedWallet = update(wallet, with: assetVisibility)
        return updatedWallet
    }

    private func update(
        _ wallet: MetaAccountModel,
        with assetVisibility: AssetVisibility
    ) -> MetaAccountModel {
        var assetVivibilities = wallet.assetsVisibility.filter { $0.assetId != assetVisibility.assetId }
        assetVivibilities.append(assetVisibility)
        let updatedWallet = wallet.replacingAssetsVisibility(assetVivibilities)
        return updatedWallet
    }
}
