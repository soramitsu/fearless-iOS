import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils

final class TransactionDetailsViewModelFactory {
    let address: String
    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let dateFormatter: LocalizableResource<DateFormatter>
    let assets: [WalletAsset]

    let iconGenerator = PolkadotIconGenerator()

    init(
        address: String,
        assets: [WalletAsset],
        dateFormatter: LocalizableResource<DateFormatter>,
        amountFormatterFactory: NumberFormatterFactoryProtocol
    ) {
        self.address = address
        self.assets = assets
        self.dateFormatter = dateFormatter
        self.amountFormatterFactory = amountFormatterFactory
    }

    func populateStatus(
        into viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        locale: Locale
    ) {
        let viewModel: WalletNewFormDetailsViewModel

        let title = R.string.localizable
            .transactionDetailStatus(preferredLanguages: locale.rLanguages)

        switch data.status {
        case .commited:
            let details = R.string.localizable
                .transactionStatusCompleted(preferredLanguages: locale.rLanguages)
            viewModel = WalletNewFormDetailsViewModel(
                title: title,
                titleIcon: nil,
                details: details,
                detailsIcon: R.image.iconValid()
            )
        case .pending:
            let details = R.string.localizable
                .transactionStatusPending(preferredLanguages: locale.rLanguages)
            viewModel = WalletNewFormDetailsViewModel(
                title: title,
                titleIcon: nil,
                details: details,
                detailsIcon: R.image.iconTxPending()
            )
        case .rejected:
            let details = R.string.localizable
                .transactionStatusFailed(preferredLanguages: locale.rLanguages)
            viewModel = WalletNewFormDetailsViewModel(
                title: title,
                titleIcon: nil,
                details: details,
                detailsIcon: R.image.iconInvalid()
            )
        }

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    func populateTime(
        into viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        locale: Locale
    ) {
        let transactionDate = Date(timeIntervalSince1970: TimeInterval(data.timestamp))

        let timeDetails = dateFormatter.value(for: locale).string(from: transactionDate)

        let title = R.string.localizable
            .transactionDetailDate(preferredLanguages: locale.rLanguages)
        let viewModel = WalletNewFormDetailsViewModel(
            title: title,
            titleIcon: nil,
            details: timeDetails,
            detailsIcon: nil
        )

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    func populateAmount(
        into viewModelList: inout [WalletFormViewBindingProtocol],
        title: String,
        data: AssetTransactionData,
        locale: Locale
    ) {
        guard let asset = assets.first(where: { $0.identifier == data.assetId }) else {
            return
        }

        let amount = data.amount.decimalValue

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset)

        guard let displayAmount = formatter.value(for: locale).string(from: amount) else {
            return
        }

        let viewModel = WalletNewFormDetailsViewModel(
            title: title,
            titleIcon: nil,
            details: displayAmount,
            detailsIcon: nil
        )

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    func populateTitleWithDetails(
        into viewModelList: inout [WalletFormViewBindingProtocol],
        title: String,
        details: String
    ) {
        let viewModel = WalletNewFormDetailsViewModel(
            title: title,
            titleIcon: nil,
            details: details,
            detailsIcon: nil
        )

        let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
        viewModelList.append(separator)
    }

    func populateFeeAmount(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        locale: Locale
    ) {
        let asset = assets.first(where: { $0.identifier == data.assetId })

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset).value(for: locale)

        for fee in data.fees where fee.assetId == data.assetId {
            guard let amount = formatter.string(from: fee.amount.decimalValue) else {
                continue
            }

            let title = R.string.localizable.walletSendFeeTitle(preferredLanguages: locale.rLanguages)

            let viewModel = WalletNewFormDetailsViewModel(
                title: title,
                titleIcon: nil,
                details: amount,
                detailsIcon: nil
            )

            let separator = WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom])
            viewModelList.append(separator)
        }
    }

    func populateTransactionId(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        chain: Chain,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        let title = R.string.localizable
            .transactionDetailsHashTitle(preferredLanguages: locale.rLanguages)

        let actionIcon = R.image.iconMore()

        let command = WalletExtrinsicOpenCommand(
            extrinsicHash: data.transactionId,
            chain: chain,
            commandFactory: commandFactory,
            locale: locale
        )

        let viewModel = WalletCompoundDetailsViewModel(
            title: title,
            details: data.transactionId,
            mainIcon: nil,
            actionIcon: actionIcon,
            command: command,
            enabled: true
        )
        viewModelList.append(viewModel)
    }

    func populatePeerViewModel(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        title: String,
        address: String,
        chain: Chain,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        let icon: UIImage? = try? iconGenerator.generateFromAddress(address)
            .imageWithFillColor(
                R.color.colorWhite()!,
                size: UIConstants.smallAddressIconSize,
                contentScale: UIScreen.main.scale
            )

        let actionIcon = R.image.iconMore()

        let command = WalletAccountOpenCommand(
            address: address,
            chain: chain,
            commandFactory: commandFactory,
            locale: locale
        )

        let viewModel = WalletCompoundDetailsViewModel(
            title: title,
            details: address,
            mainIcon: icon,
            actionIcon: actionIcon,
            command: command,
            enabled: true
        )
        viewModelList.append(viewModel)
    }
}

extension TransactionDetailsViewModelFactory: WalletTransactionDetailsFactoryOverriding {
    func createViewModelsFromTransaction(
        data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) -> [WalletFormViewBindingProtocol]? {
        guard let transactionType = TransactionType(rawValue: data.type) else {
            return nil
        }

        switch transactionType {
        case .incoming, .outgoing:
            return createTransferViewModels(
                data: data,
                commandFactory: commandFactory,
                locale: locale
            )
        case .reward, .slash:
            return createRewardAndSlashViewModels(
                isReward: transactionType == .reward,
                data: data,
                commandFactory: commandFactory,
                locale: locale
            )
        case .extrinsic:
            return createExtrinsViewModels(
                data: data,
                commandFactory: commandFactory,
                locale: locale
            )
        }
    }

    func createAccessoryViewModelFromTransaction(
        data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) -> AccessoryViewModelProtocol? {
        guard let transactionType = TransactionType(rawValue: data.type) else {
            return nil
        }

        switch transactionType {
        case .incoming, .outgoing:
            return createTransferAccessoryViewModel(
                data: data,
                commandFactory: commandFactory,
                locale: locale
            )
        case .reward, .slash:
            return createRewardAndSlashAccessoryViewModel(
                data: data,
                commandFactory: commandFactory,
                locale: locale
            )
        case .extrinsic:
            return createExtrinsicAccessoryViewModel(
                data: data,
                commandFactory: commandFactory,
                locale: locale
            )
        }
    }
}
