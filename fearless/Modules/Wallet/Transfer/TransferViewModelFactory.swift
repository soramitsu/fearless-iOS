import Foundation
import CommonWallet
import IrohaCrypto
import FearlessUtils
import SoraFoundation

final class TransferViewModelFactory: TransferViewModelFactoryOverriding {
    weak var commandFactory: WalletCommandFactoryProtocol?

    let assets: [WalletAsset]
    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    init(
        assets: [WalletAsset],
        amountFormatterFactory: NumberFormatterFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.assets = assets
        self.amountFormatterFactory = amountFormatterFactory
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    func createFeeViewModel(
        _: TransferInputState,
        fee: Fee,
        payload _: TransferPayload,
        locale: Locale
    ) throws -> FeeViewModelProtocol? {
        guard
            let asset = assets
            .first(where: { $0.identifier == fee.feeDescription.assetId })
        else {
            return nil
        }

        let title = R.string.localizable.commonNetworkFee(preferredLanguages: locale.rLanguages)

        let formatter = amountFormatterFactory.createFeeTokenFormatter(for: asset).value(for: locale)

        let amount = formatter
            .stringFromDecimal(fee.feeDescription.parameters.first?.decimalValue ?? 0) ?? ""

        return FeeViewModel(
            title: title,
            details: amount,
            isLoading: false,
            allowsEditing: false
        )
    }

    func createDescriptionViewModel(
        _: TransferInputState,
        details _: String?,
        payload _: TransferPayload,
        locale _: Locale
    ) throws
        -> WalletOverridingResult<DescriptionInputViewModelProtocol?>? {
        WalletOverridingResult(item: nil)
    }

    func createSelectedAssetViewModel(
        _: TransferInputState,
        selectedAssetState _: SelectedAssetState,
        payload _: TransferPayload,
        locale _: Locale
    ) throws -> AssetSelectionViewModelProtocol? {
        nil
    }

    func createAssetSelectionTitle(
        _: TransferInputState,
        payload: TransferPayload,
        locale: Locale
    ) throws -> String? {
        guard let asset = assets
            .first(where: { $0.identifier == payload.receiveInfo.assetId })
        else {
            return nil
        }

        return asset.name.value(for: locale)
    }

    func createReceiverViewModel(
        _: TransferInputState,
        payload: TransferPayload,
        locale: Locale
    ) throws
        -> MultilineTitleIconViewModelProtocol? {
        guard
            let asset = assets
            .first(where: { $0.identifier == payload.receiveInfo.assetId }),
            let chain = WalletAssetId(rawValue: asset.identifier)?.chain,
            let commandFactory = commandFactory
        else {
            return nil
        }

        let header = R.string.localizable
            .walletSendReceiverTitle(preferredLanguages: locale.rLanguages)

        let iconGenerator = PolkadotIconGenerator()
        let icon = try? iconGenerator.generateFromAddress(payload.receiverName)
            .imageWithFillColor(
                R.color.colorWhite()!,
                size: UIConstants.smallAddressIconSize,
                contentScale: UIScreen.main.scale
            )

        let command = WalletAccountOpenCommand(
            address: payload.receiverName,
            chain: chain,
            commandFactory: commandFactory,
            locale: locale
        )

        let viewModel = WalletCompoundDetailsViewModel(
            title: header,
            details: payload.receiverName,
            mainIcon: icon,
            actionIcon: R.image.iconMore(),
            command: command,
            enabled: true
        )

        return viewModel
    }

    func createAccessoryViewModel(
        _: TransferInputState,
        payload _: TransferPayload?,
        locale: Locale
    ) throws -> AccessoryViewModelProtocol? {
        let action = R.string.localizable.commonContinue(preferredLanguages: locale.rLanguages)
        return AccessoryViewModel(title: "", action: action)
    }

    func createAmountViewModel(
        _ inputState: TransferInputState,
        payload: TransferPayload,
        locale: Locale
    ) throws -> AmountInputViewModelProtocol? {
        guard
            let asset = assets
            .first(where: { $0.identifier == payload.receiveInfo.assetId }),
            let assetId = WalletAssetId(rawValue: asset.identifier)
        else {
            return nil
        }

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset).value(for: locale)

        let balanceContext = BalanceContext(context: inputState.balance?.context ?? [:])
        let balance = formatter.stringFromDecimal(balanceContext.available) ?? ""

        let amountInputViewModel = balanceViewModelFactory.createBalanceInputViewModel(
            inputState.amount
        ).value(for: locale)

        let fee = inputState.metadata?.feeDescriptions.first?.parameters.first?.decimalValue ?? .zero

        let priceContext = TransferMetadataContext(context: inputState.metadata?.context ?? [:])
        let priceData = priceContext.price > .zero ?
            PriceData(price: priceContext.price.stringWithPointSeparator, usdDayChange: nil) :
            nil

        return RichAmountInputViewModel(
            amountInputViewModel: amountInputViewModel,
            balanceViewModelFactory: balanceViewModelFactory,
            tokenFormatter: formatter,
            symbol: asset.symbol,
            icon: assetId.icon,
            balance: balance,
            price: nil,
            priceData: priceData,
            decimalBalance: balanceContext.available,
            fee: fee,
            limit: TransferConstants.maxAmount
        )
    }
}
