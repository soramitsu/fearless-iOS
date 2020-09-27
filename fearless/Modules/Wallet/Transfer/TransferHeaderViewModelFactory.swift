import Foundation
import CommonWallet

final class TransferHeaderViewModelFactory: OperationDefinitionHeaderModelFactoryProtocol {
    func createAmountTitle(assetId: String,
                           receiverId: String?,
                           locale: Locale) -> MultilineTitleIconViewModelProtocol? {
        let text = R.string.localizable.walletSendAmountTitle(preferredLanguages: locale.rLanguages)
        return MultilineTitleIconViewModel(text: text)
    }

    func createAssetTitle(assetId: String,
                          receiverId: String?,
                          locale: Locale) -> MultilineTitleIconViewModelProtocol? {
        let text = R.string.localizable.walletSendAssetTitle(preferredLanguages: locale.rLanguages)
        return MultilineTitleIconViewModel(text: text)
    }

    func createReceiverTitle(assetId: String,
                             receiverId: String?,
                             locale: Locale) -> MultilineTitleIconViewModelProtocol? {
        let text = R.string.localizable.walletSendReceiverTitle(preferredLanguages: locale.rLanguages)
        return MultilineTitleIconViewModel(text: text)
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
