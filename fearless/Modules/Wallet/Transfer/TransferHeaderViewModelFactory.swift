import Foundation
import CommonWallet

final class TransferHeaderViewModelFactory: OperationDefinitionHeaderModelFactoryProtocol {
    func createAmountTitle(
        assetId _: String,
        receiverId _: String?,
        locale _: Locale
    ) -> MultilineTitleIconViewModelProtocol? {
        nil
    }

    func createAssetTitle(
        assetId _: String,
        receiverId _: String?,
        locale _: Locale
    ) -> MultilineTitleIconViewModelProtocol? {
        nil
    }

    func createReceiverTitle(
        assetId _: String,
        receiverId _: String?,
        locale _: Locale
    ) -> MultilineTitleIconViewModelProtocol? {
        nil
    }

    func createFeeTitleForDescription(
        assetId _: String,
        receiverId _: String?,
        feeDescription _: Fee,
        locale _: Locale
    ) -> MultilineTitleIconViewModelProtocol? {
        nil
    }

    func createDescriptionTitle(
        assetId _: String,
        receiverId _: String?,
        locale _: Locale
    ) -> MultilineTitleIconViewModelProtocol? {
        nil
    }
}
