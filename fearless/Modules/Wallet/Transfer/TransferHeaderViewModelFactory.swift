import Foundation
import CommonWallet

final class TransferHeaderViewModelFactory: OperationDefinitionHeaderModelFactoryProtocol {
    func createAmountTitle(assetId: String,
                           receiverId: String?,
                           locale: Locale) -> MultilineTitleIconViewModelProtocol? {
        nil
    }

    func createAssetTitle(assetId: String,
                          receiverId: String?,
                          locale: Locale) -> MultilineTitleIconViewModelProtocol? {
        return nil
    }

    func createReceiverTitle(assetId: String,
                             receiverId: String?,
                             locale: Locale) -> MultilineTitleIconViewModelProtocol? {
        return nil
    }

    func createFeeTitleForDescription(assetId: String,
                                      receiverId: String?,
                                      feeDescription: Fee, locale: Locale)
        -> MultilineTitleIconViewModelProtocol? {
        nil
    }

    func createDescriptionTitle(assetId: String,
                                receiverId: String?,
                                locale: Locale) -> MultilineTitleIconViewModelProtocol? {
        nil
    }
}
