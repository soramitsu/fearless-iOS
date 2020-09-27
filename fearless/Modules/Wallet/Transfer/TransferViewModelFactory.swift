import Foundation
import CommonWallet
import IrohaCrypto

final class TransferViewModelFactory: TransferViewModelFactoryOverriding {
    let assets: [WalletAsset]
    let amountFormatter: NumberFormatterFactoryProtocol

    init(assets: [WalletAsset], amountFormatter: NumberFormatterFactoryProtocol) {
        self.assets = assets
        self.amountFormatter = amountFormatter
    }

    func createFeeViewModel(_ inputState: TransferInputState,
                            fee: Fee,
                            payload: TransferPayload,
                            locale: Locale) throws -> FeeViewModelProtocol? {
        guard
            let asset = assets
                .first(where: { $0.identifier == fee.feeDescription.assetId }) else {
            return nil
        }

        let title = R.string.localizable.walletSendFeeTitle(preferredLanguages: locale.rLanguages)

        let formatter = amountFormatter.createTokenFormatter(for: asset).value(for: locale)

        let amount = formatter
            .string(from: fee.feeDescription.parameters.first?.decimalValue ?? 0) ?? ""

        return FeeViewModel(title: title,
                            details: amount,
                            isLoading: false,
                            allowsEditing: false)
    }

    func createDescriptionViewModel(_ inputState: TransferInputState,
                                    details: String?,
                                    payload: TransferPayload,
                                    locale: Locale) throws
        -> DescriptionInputViewModelProtocol? {
        return nil
    }

    func createSelectedAssetViewModel(_ inputState: TransferInputState,
                                      selectedAssetState: SelectedAssetState,
                                      payload: TransferPayload,
                                      locale: Locale) throws -> AssetSelectionViewModelProtocol? {
        guard
            let asset = assets
                .first(where: { $0.identifier == payload.receiveInfo.assetId }),
            let assetId = WalletAssetId(rawValue: asset.identifier) else {
            return nil
        }

        let formatter = amountFormatter.createTokenFormatter(for: asset).value(for: locale)

        let amount = formatter.string(from: inputState.balance?.balance.decimalValue ?? 0.0) ?? ""

        return AssetSelectionViewModel(title: asset.name.value(for: locale),
                                       subtitle: "",
                                       details: amount,
                                       icon: assetId.icon,
                                       state: selectedAssetState)
    }

    func createAssetSelectionTitle(_ inputState: TransferInputState,
                                   payload: TransferPayload,
                                   locale: Locale) throws -> String? {
        guard let asset = assets
            .first(where: { $0.identifier == payload.receiveInfo.assetId }) else {
            return nil
        }

        return asset.name.value(for: locale)
    }

    func createReceiverViewModel(_ inputState: TransferInputState,
                                 payload: TransferPayload,
                                 locale: Locale) throws
        -> MultilineTitleIconViewModelProtocol? {
        MultilineTitleIconViewModel(text: payload.receiverName)
    }

    func createAccessoryViewModel(_ inputState: TransferInputState,
                                  payload: TransferPayload?,
                                  locale: Locale) throws -> AccessoryViewModelProtocol? {
        let action = R.string.localizable.commonContinue(preferredLanguages: locale.rLanguages)
        return AccessoryViewModel(title: "", action: action)
    }
}
