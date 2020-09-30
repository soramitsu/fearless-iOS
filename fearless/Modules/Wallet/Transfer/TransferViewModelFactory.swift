import Foundation
import CommonWallet
import IrohaCrypto
import FearlessUtils

final class TransferViewModelFactory: TransferViewModelFactoryOverriding {
    weak var commandFactory: WalletCommandFactoryProtocol?

    let assets: [WalletAsset]
    let amountFormatterFactory: NumberFormatterFactoryProtocol

    init(assets: [WalletAsset], amountFormatterFactory: NumberFormatterFactoryProtocol) {
        self.assets = assets
        self.amountFormatterFactory = amountFormatterFactory
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

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset).value(for: locale)

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
        -> WalletOverridingResult<DescriptionInputViewModelProtocol?>? {
        return WalletOverridingResult(item: nil)
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

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset).value(for: locale)

        let amount = formatter.string(from: inputState.balance?.balance.decimalValue ?? 0.0) ?? ""

        let subtitle = R.string.localizable
            .walletSendBalanceTitle(preferredLanguages: locale.rLanguages)

        return AssetSelectionViewModel(title: asset.name.value(for: locale),
                                       subtitle: subtitle,
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

        let iconGenerator = PolkadotIconGenerator()
        let icon = try? iconGenerator.generateFromAddress(payload.receiverName)
            .imageWithFillColor(R.color.colorWhite()!,
                                size: CGSize(width: 24.0, height: 24.0),
                                contentScale: UIScreen.main.scale)

        let alertTitle = R.string.localizable
            .commonCopied(preferredLanguages: locale.rLanguages)
        let copyCommand = WalletCopyCommand(copyingString: payload.receiverName,
                                            alertTitle: alertTitle)
        copyCommand.commandFactory = commandFactory

        return WalletAccountViewModel(text: payload.receiverName,
                                      icon: icon,
                                      copyCommand: copyCommand)
    }

    func createAccessoryViewModel(_ inputState: TransferInputState,
                                  payload: TransferPayload?,
                                  locale: Locale) throws -> AccessoryViewModelProtocol? {
        let action = R.string.localizable.commonContinue(preferredLanguages: locale.rLanguages)
        return AccessoryViewModel(title: "", action: action)
    }
}
