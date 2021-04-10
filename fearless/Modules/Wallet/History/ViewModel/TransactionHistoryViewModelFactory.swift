import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils

enum TransactionHistoryViewModelFactoryError: Error {
    case missingAsset
    case unsupportedType
}

final class TransactionHistoryViewModelFactory {
    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let dateFormatter: LocalizableResource<DateFormatter>
    let assets: [WalletAsset]
    let chain: Chain

    let iconGenerator = PolkadotIconGenerator()

    init(
        amountFormatterFactory: NumberFormatterFactoryProtocol,
        dateFormatter: LocalizableResource<DateFormatter>,
        assets: [WalletAsset],
        chain: Chain
    ) {
        self.amountFormatterFactory = amountFormatterFactory
        self.dateFormatter = dateFormatter
        self.assets = assets
        self.chain = chain
    }

    private func createTransferItemFromData(
        _ data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale,
        txType: TransactionType
    ) throws -> WalletViewModelProtocol {
        guard let asset = assets.first(where: { $0.identifier == data.assetId }) else {
            throw TransactionHistoryViewModelFactoryError.missingAsset
        }

        let amount = amountFormatterFactory.createTokenFormatter(for: asset)
            .value(for: locale)
            .string(from: data.amount.decimalValue)
            ?? ""

        let time = dateFormatter.value(for: locale)
            .string(from: Date(timeIntervalSince1970: TimeInterval(data.timestamp)))

        let imageViewModel: WalletImageViewModelProtocol?
        let icon: UIImage?

        if let address = data.peerName {
            icon = try? iconGenerator.generateFromAddress(address)
                .imageWithFillColor(
                    R.color.colorWhite()!,
                    size: UIConstants.normalAddressIconSize,
                    contentScale: UIScreen.main.scale
                )
        } else {
            icon = nil
        }

        if let currentIcon = icon {
            imageViewModel = WalletStaticImageViewModel(staticImage: currentIcon)
        } else {
            imageViewModel = nil
        }

        let command = commandFactory.prepareTransactionDetailsCommand(with: data)

        return HistoryItemViewModel(
            title: data.peerName ?? "",
            subtitle: "Transfer",
            amount: amount,
            time: time,
            type: txType,
            status: data.status,
            imageViewModel: imageViewModel,
            command: command
        )
    }

    private func createRewardOrSlashItemFromData(
        _ data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale,
        txType: TransactionType
    ) throws -> WalletViewModelProtocol {
        guard let asset = assets.first(where: { $0.identifier == data.assetId }) else {
            throw TransactionHistoryViewModelFactoryError.missingAsset
        }

        let amount = amountFormatterFactory.createTokenFormatter(for: asset)
            .value(for: locale)
            .string(from: data.amount.decimalValue)
            ?? ""

        let time = dateFormatter.value(for: locale)
            .string(from: Date(timeIntervalSince1970: TimeInterval(data.timestamp)))

        let imageViewModel: WalletImageViewModelProtocol?

        if let icon = R.image.iconRewardAndSlashes() {
            imageViewModel = WalletStaticImageViewModel(staticImage: icon)
        } else {
            imageViewModel = nil
        }

        let command = commandFactory.prepareTransactionDetailsCommand(with: data)

        let title = txType == .reward ? "Reward" : "Slash"

        return HistoryItemViewModel(
            title: title,
            subtitle: "Staking",
            amount: amount,
            time: time,
            type: txType,
            status: data.status,
            imageViewModel: imageViewModel,
            command: command
        )
    }

    private func createExtrinsicItemFromData(
        _ data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale,
        txType: TransactionType
    ) throws -> WalletViewModelProtocol {
        guard let asset = assets.first(where: { $0.identifier == data.assetId }) else {
            throw TransactionHistoryViewModelFactoryError.missingAsset
        }

        let amount = amountFormatterFactory.createTokenFormatter(for: asset)
            .value(for: locale)
            .string(from: data.amount.decimalValue)
            ?? ""

        let time = dateFormatter.value(for: locale)
            .string(from: Date(timeIntervalSince1970: TimeInterval(data.timestamp)))

        let imageViewModel: WalletImageViewModelProtocol?

        if let icon = chain.extrinsicIcon {
            imageViewModel = WalletStaticImageViewModel(staticImage: icon)
        } else {
            imageViewModel = nil
        }

        let command = commandFactory.prepareTransactionDetailsCommand(with: data)

        return HistoryItemViewModel(
            title: data.peerLastName?.displayCall ?? "",
            subtitle: data.peerFirstName?.displayModule ?? "",
            amount: amount,
            time: time,
            type: txType,
            status: data.status,
            imageViewModel: imageViewModel,
            command: command
        )
    }
}

extension TransactionHistoryViewModelFactory: HistoryItemViewModelFactoryProtocol {
    func createItemFromData(
        _ data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) throws -> WalletViewModelProtocol {
        guard let transactionType = TransactionType(rawValue: data.type) else {
            throw TransactionHistoryViewModelFactoryError.unsupportedType
        }

        switch transactionType {
        case .incoming, .outgoing:
            return try createTransferItemFromData(
                data,
                commandFactory: commandFactory,
                locale: locale,
                txType: transactionType
            )
        case .reward, .slash:
            return try createRewardOrSlashItemFromData(
                data,
                commandFactory: commandFactory,
                locale: locale,
                txType: transactionType
            )
        case .extrinsic:
            return try createExtrinsicItemFromData(
                data,
                commandFactory: commandFactory,
                locale: locale,
                txType: transactionType
            )
        }
    }
}
