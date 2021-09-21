import Foundation
import CommonWallet
import FearlessUtils
import IrohaCrypto
import SoraKeystore

final class TransferConfirmViewModelFactory {
    weak var commandFactory: WalletCommandFactoryProtocol?

    private lazy var addressFactory = SS58AddressFactory()
    private lazy var settings = SettingsManager.shared

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

    private func getPriceDataFrom(_ transferInfo: TransferInfo) -> PriceData? {
        let priceContext = BalanceContext(context: transferInfo.context ?? [:])
        let price = priceContext.price

        guard price > 0.0 else { return nil }

        return PriceData(price: price.stringWithPointSeparator, usdDayChange: nil)
    }

    func populateFee(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        payload: ConfirmationPayload,
        locale: Locale
    ) {
        guard let asset = assets.first(where: { $0.identifier == payload.transferInfo.asset }) else {
            return
        }

        let formatter = amountFormatterFactory.createFeeTokenFormatter(for: asset)

        for fee in payload.transferInfo.fees {
            let decimalAmount = fee.value.decimalValue

            guard let amount = formatter.value(for: locale).stringFromDecimal(decimalAmount) else {
                return
            }

            let title = R.string.localizable.commonNetworkFee(preferredLanguages: locale.rLanguages)
            let viewModel = WalletNewFormDetailsViewModel(
                title: title,
                titleIcon: nil,
                details: amount,
                detailsIcon: nil
            )
            viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: [.none]))
        }
    }

    func populateSendingAmount(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        payload: ConfirmationPayload,
        locale: Locale
    ) {
        guard let asset = assets
            .first(where: { $0.identifier == payload.transferInfo.asset }),
            let assetId = WalletAssetId(rawValue: asset.identifier)
        else {
            return
        }

        let formatter = amountFormatterFactory.createInputFormatter(for: asset).value(for: locale)
        let balanceFormatter = amountFormatterFactory.createTokenFormatter(for: asset).value(for: locale)

        let decimalAmount = payload.transferInfo.amount.decimalValue

        guard let amount = formatter.string(from: decimalAmount as NSNumber) else {
            return
        }

        let balanceContext = BalanceContext(context: payload.transferInfo.context ?? [:])
        let balance = balanceFormatter.stringFromDecimal(balanceContext.available) ?? ""

        let title = R.string.localizable.walletSendAmountTitle(preferredLanguages: locale.rLanguages)
        let baseViewModel = WalletFormSpentAmountModel(title: title, amount: amount)

        let priceData = getPriceDataFrom(payload.transferInfo)

        let viewModel = RichAmountDisplayViewModel(
            balanceViewModelFactory: balanceViewModelFactory,
            displayViewModel: baseViewModel,
            icon: assetId.icon,
            symbol: asset.symbol,
            balance: balance,
            priceData: priceData
        )

        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: .none))
    }

    func populateReceiver(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        payload: ConfirmationPayload,
        chain: Chain,
        locale: Locale
    ) {
        guard let commandFactory = commandFactory else {
            return
        }

        let headerTitle = R.string.localizable
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
            title: headerTitle,
            details: payload.receiverName,
            mainIcon: icon,
            actionIcon: R.image.iconMore(),
            command: command,
            enabled: true
        )

        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: [.none]))
    }

    func populateSender(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        payload: ConfirmationPayload,
        chain: Chain,
        locale: Locale
    ) {
        guard let commandFactory = commandFactory else { return }

        let senderAddress: AccountAddress? = {
            if let selectedAccount = settings.selectedAccount {
                return selectedAccount.address
            } else {
                return try? addressFactory.addressFromAccountId(
                    data: Data(hexString: payload.transferInfo.source),
                    type: chain.addressType
                )
            }
        }()

        guard let senderAddress = senderAddress else { return }

        let headerTitle = R.string.localizable
            .transactionDetailsFrom(preferredLanguages: locale.rLanguages)

        let iconGenerator = PolkadotIconGenerator()
        let icon = try? iconGenerator.generateFromAddress(senderAddress)
            .imageWithFillColor(
                R.color.colorWhite()!,
                size: UIConstants.smallAddressIconSize,
                contentScale: UIScreen.main.scale
            )

        let command = WalletAccountOpenCommand(
            address: senderAddress,
            chain: chain,
            commandFactory: commandFactory,
            locale: locale
        )

        let viewModel = WalletCompoundDetailsViewModel(
            title: headerTitle,
            details: settings.selectedAccount?.username ?? senderAddress,
            mainIcon: icon,
            actionIcon: R.image.iconMore(),
            command: command,
            enabled: true
        )

        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: [.none]))
    }
}

extension TransferConfirmViewModelFactory: TransferConfirmationViewModelFactoryOverriding {
    func createViewModelsFromPayload(
        _ payload: ConfirmationPayload,
        locale: Locale
    ) -> [WalletFormViewBindingProtocol]? {
        guard let chain = WalletAssetId(rawValue: payload.transferInfo.asset)?.chain else {
            return nil
        }

        var viewModelList: [WalletFormViewBindingProtocol] = []

        populateSender(in: &viewModelList, payload: payload, chain: chain, locale: locale)
        populateReceiver(in: &viewModelList, payload: payload, chain: chain, locale: locale)
        populateSendingAmount(in: &viewModelList, payload: payload, locale: locale)

        return viewModelList
    }

    func createAccessoryViewModelFromPayload(
        _ payload: ConfirmationPayload,
        locale: Locale
    ) -> AccessoryViewModelProtocol? {
        guard let asset = assets.first(where: { $0.identifier == payload.transferInfo.asset }) else {
            return nil
        }

        let fee = payload.transferInfo.fees
            .map(\.value.decimalValue)
            .reduce(0.0, +)

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset)

        guard let amount = formatter.value(for: locale).stringFromDecimal(fee) else {
            return nil
        }

        let actionTitle = R.string.localizable.commonConfirm(preferredLanguages: locale.rLanguages)
        let title = R.string.localizable.commonNetworkFee(preferredLanguages: locale.rLanguages)

        return TransferConfirmAccessoryViewModel(
            title: title,
            icon: nil,
            action: actionTitle,
            numberOfLines: 1,
            amount: amount,
            shouldAllowAction: true
        )
    }
}
