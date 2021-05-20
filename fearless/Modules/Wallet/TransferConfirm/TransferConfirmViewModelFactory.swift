import Foundation
import CommonWallet
import FearlessUtils

final class TransferConfirmViewModelFactory {
    weak var commandFactory: WalletCommandFactoryProtocol?

    let assets: [WalletAsset]
    let amountFormatterFactory: NumberFormatterFactoryProtocol

    init(assets: [WalletAsset], amountFormatterFactory: NumberFormatterFactoryProtocol) {
        self.assets = assets
        self.amountFormatterFactory = amountFormatterFactory
    }

    func populateAsset(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        payload: ConfirmationPayload,
        locale: Locale
    ) {
        guard
            let asset = assets
            .first(where: { $0.identifier == payload.transferInfo.asset }),
            let assetId = WalletAssetId(rawValue: asset.identifier)
        else {
            return
        }

        let headerTitle = R.string.localizable.walletSendAssetTitle(preferredLanguages: locale.rLanguages)

        let subtitle: String = R.string.localizable
            .walletSendAvailableBalance(preferredLanguages: locale.rLanguages)

        let context = BalanceContext(context: payload.transferInfo.context ?? [:])

        let amountFormatter = amountFormatterFactory.createTokenFormatter(for: asset)
        let details = amountFormatter.value(for: locale).stringFromDecimal(context.available) ?? ""

        let detailsCommand: WalletCommandProtocol?

        if let commandFactory = commandFactory {
            let transferring = payload.transferInfo.amount.decimalValue
            let fee = payload.transferInfo.fees.reduce(Decimal(0.0)) { $0 + $1.value.decimalValue }
            let remaining = context.total - (transferring + fee)
            let transferState = TransferExistentialState(
                totalAmount: context.total,
                availableAmount: context.available,
                totalAfterTransfer: remaining,
                existentialDeposit: context.minimalBalance
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

        let selectedState = SelectedAssetState(isSelecting: false, canSelect: false)
        let tokenViewModel = WalletTokenViewModel(
            header: headerTitle,
            title: assetId.titleForLocale(locale),
            subtitle: subtitle,
            details: details,
            icon: assetId.icon,
            state: selectedState,
            detailsCommand: detailsCommand
        )

        viewModelList.append(WalletFormSeparatedViewModel(content: tokenViewModel, borderType: [.bottom]))
    }

    func populateFee(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        payload: ConfirmationPayload,
        locale: Locale
    ) {
        guard let asset = assets.first(where: { $0.identifier == payload.transferInfo.asset }) else {
            return
        }

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset)

        for fee in payload.transferInfo.fees {
            let decimalAmount = fee.value.decimalValue

            guard let amount = formatter.value(for: locale).stringFromDecimal(decimalAmount) else {
                return
            }

            let title = R.string.localizable.walletSendFeeTitle(preferredLanguages: locale.rLanguages)
            let viewModel = WalletNewFormDetailsViewModel(
                title: title,
                titleIcon: nil,
                details: amount,
                detailsIcon: nil
            )
            viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom]))
        }
    }

    func populateSendingAmount(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        payload: ConfirmationPayload,
        locale: Locale
    ) {
        guard let asset = assets.first(where: { $0.identifier == payload.transferInfo.asset }) else {
            return
        }

        let formatter = amountFormatterFactory.createInputFormatter(for: asset)

        let decimalAmount = payload.transferInfo.amount.decimalValue

        guard let amount = formatter.value(for: locale).string(from: decimalAmount as NSNumber) else {
            return
        }

        let title = R.string.localizable.walletSendAmountTitle(preferredLanguages: locale.rLanguages)
        let viewModel = WalletFormSpentAmountModel(title: title, amount: amount)
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
            enabled: false
        )

        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom]))
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

        populateAsset(in: &viewModelList, payload: payload, locale: locale)
        populateReceiver(in: &viewModelList, payload: payload, chain: chain, locale: locale)
        populateSendingAmount(in: &viewModelList, payload: payload, locale: locale)
        populateFee(in: &viewModelList, payload: payload, locale: locale)

        return viewModelList
    }

    func createAccessoryViewModelFromPayload(
        _ payload: ConfirmationPayload,
        locale: Locale
    ) -> AccessoryViewModelProtocol? {
        guard let asset = assets.first(where: { $0.identifier == payload.transferInfo.asset }) else {
            return nil
        }

        var decimalAmount = payload.transferInfo.amount.decimalValue

        for fee in payload.transferInfo.fees {
            decimalAmount += fee.value.decimalValue
        }

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset)

        guard let amount = formatter.value(for: locale).stringFromDecimal(decimalAmount) else {
            return nil
        }

        let actionTitle = R.string.localizable.walletSendConfirmTitle(preferredLanguages: locale.rLanguages)
        let title = R.string.localizable.walletTransferTotalTitle(preferredLanguages: locale.rLanguages)

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
