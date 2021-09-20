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

    // TODO: Move to amount view
    /*
     guard
         let asset = assets
         .first(where: { $0.identifier == payload.receiveInfo.assetId }),
         let assetId = WalletAssetId(rawValue: asset.identifier)
     else {
         return nil
     }

     let formatter = amountFormatterFactory.createTokenFormatter(for: asset).value(for: locale)

     let balanceContext = BalanceContext(context: inputState.balance?.context ?? [:])
     let amount = formatter.stringFromDecimal(balanceContext.available) ?? ""

     let subtitle = R.string.localizable
         .walletSendAvailableBalance(preferredLanguages: locale.rLanguages)

     let detailsCommand: WalletCommandProtocol?

     if let context = inputState.balance?.context, let commandFactory = commandFactory {
         let balanceContext = BalanceContext(context: context)
         let transferring = inputState.amount ?? .zero
         let fee = inputState.metadata?.feeDescriptions.first?.parameters.first?.decimalValue ?? .zero
         let remaining = balanceContext.total - (transferring + fee)
         let transferState = TransferExistentialState(
             totalAmount: balanceContext.total,
             availableAmount: balanceContext.available,
             totalAfterTransfer: remaining,
             existentialDeposit: balanceContext.minimalBalance
         )

         let amountFormatter = amountFormatterFactory.createDisplayFormatter(for: asset)

         detailsCommand = ExistentialDepositInfoCommand(
             transferState: transferState,
             amountFormatter: amountFormatter,
             commandFactory: commandFactory
         )
     } else {
         detailsCommand = nil
     }

     let header = R.string.localizable.walletSendAssetTitle(preferredLanguages: locale.rLanguages)

     let viewModel = WalletTokenViewModel(
         header: header,
         title: asset.name.value(for: locale),
         subtitle: subtitle,
         details: amount,
         icon: assetId.icon,
         state: selectedAssetState,
         detailsCommand: detailsCommand
     )
     */

    // TODO: Check what it does
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

// TODO: Move into separate file
protocol RichAmountInputViewModelProtocol: AmountInputViewModelProtocol, AssetBalanceViewModelProtocol {
    var balanceViewModelFactory: BalanceViewModelFactoryProtocol { get }
    var priceData: PriceData? { get }
    var displayPrice: LocalizableResource<String> { get }
    var displayBalance: LocalizableResource<String> { get }
    var decimalBalance: Decimal? { get }
    var fee: Decimal? { get }
    var limit: Decimal { get }
}

final class RichAmountInputViewModel: RichAmountInputViewModelProtocol {
    let amountInputViewModel: AmountInputViewModelProtocol
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    let symbol: String
    let icon: UIImage?
    let balance: String?
    let price: String?
    let priceData: PriceData?
    let decimalBalance: Decimal?
    let fee: Decimal?
    let limit: Decimal

    var displayAmount: String {
        amountInputViewModel.displayAmount
    }

    var decimalAmount: Decimal? {
        amountInputViewModel.decimalAmount
    }

    var isValid: Bool {
        amountInputViewModel.isValid
    }

    var observable: WalletViewModelObserverContainer<AmountInputViewModelObserver> {
        amountInputViewModel.observable
    }

    var displayPrice: LocalizableResource<String> {
        LocalizableResource<String> { [self] locale in
            guard let amount = decimalAmount,
                  let priceData = priceData
            else { return "" }

            return balanceViewModelFactory.balanceFromPrice(
                amount,
                priceData: priceData
            ).value(for: locale).price ?? ""
        }
    }

    var displayBalance: LocalizableResource<String> {
        LocalizableResource<String> { locale in
            R.string.localizable
                .commonAvailableFormat(self.balance ?? "0", preferredLanguages: locale.rLanguages)
        }
    }

    init(
        amountInputViewModel: AmountInputViewModelProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        symbol: String,
        icon: UIImage?,
        balance: String?,
        price: String?,
        priceData: PriceData?,
        decimalBalance: Decimal?,
        fee: Decimal?,
        limit: Decimal
    ) {
        self.amountInputViewModel = amountInputViewModel
        self.balanceViewModelFactory = balanceViewModelFactory
        self.symbol = symbol
        self.icon = icon
        self.balance = balance
        self.price = price
        self.priceData = priceData
        self.decimalBalance = decimalBalance
        self.fee = fee
        self.limit = limit
    }

    func didReceiveReplacement(_ string: String, for range: NSRange) -> Bool {
        amountInputViewModel.didReceiveReplacement(string, for: range)
    }

    func didUpdateAmount(to newAmount: String) {
        amountInputViewModel.didUpdateAmount(to: newAmount)
    }
}
