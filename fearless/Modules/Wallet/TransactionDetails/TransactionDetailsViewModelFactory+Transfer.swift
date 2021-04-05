import Foundation
import CommonWallet
import SoraFoundation
import FearlessUtils

extension TransactionDetailsViewModelFactory {
    func createTransferViewModels(
        data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) -> [WalletFormViewBindingProtocol]? {
        guard let chain = WalletAssetId(rawValue: data.assetId)?.chain else {
            return nil
        }

        var viewModels: [WalletFormViewBindingProtocol] = []

        populateStatus(into: &viewModels, data: data, locale: locale)
        populateTime(into: &viewModels, data: data, locale: locale)
        populateTransferAmount(into: &viewModels, data: data, locale: locale)
        populateFeeAmount(in: &viewModels, data: data, locale: locale)
        populateTransactionId(
            in: &viewModels,
            data: data,
            chain: chain,
            commandFactory: commandFactory,
            locale: locale
        )

        guard let type = TransactionType(rawValue: data.type), let peerAddress = data.peerName else {
            return viewModels
        }

        if type == .incoming {
            populateSender(
                in: &viewModels,
                address: peerAddress,
                chain: chain,
                commandFactory: commandFactory,
                locale: locale
            )
            populateReceiver(
                in: &viewModels,
                address: address,
                chain: chain,
                commandFactory: commandFactory,
                locale: locale
            )
        } else {
            populateSender(
                in: &viewModels,
                address: address,
                chain: chain,
                commandFactory: commandFactory,
                locale: locale
            )
            populateReceiver(
                in: &viewModels,
                address: peerAddress,
                chain: chain,
                commandFactory: commandFactory,
                locale: locale
            )
        }

        return viewModels
    }

    func createTransferAccessoryViewModel(
        data: AssetTransactionData,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) -> AccessoryViewModelProtocol? {
        guard let asset = assets.first(where: { $0.identifier == data.assetId }) else {
            return nil
        }

        let title = R.string.localizable.walletTransferTotalTitle(preferredLanguages: locale.rLanguages)

        var decimalAmount = data.amount.decimalValue

        for fee in data.fees {
            decimalAmount += fee.amount.decimalValue
        }

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset)

        guard let amount = formatter.value(for: locale).string(from: decimalAmount) else {
            return nil
        }

        let icon: UIImage?

        if let address = data.peerName {
            icon = try? iconGenerator.generateFromAddress(address)
                .imageWithFillColor(
                    R.color.colorWhite()!,
                    size: CGSize(width: 32.0, height: 32.0),
                    contentScale: UIScreen.main.scale
                )
        } else {
            icon = nil
        }

        let receiverInfo = ReceiveInfo(
            accountId: data.peerId,
            assetId: asset.identifier,
            amount: nil,
            details: nil
        )

        let transferPayload = TransferPayload(
            receiveInfo: receiverInfo,
            receiverName: data.peerName ?? ""
        )
        let command = commandFactory.prepareTransfer(with: transferPayload)
        command.presentationStyle = .push(hidesBottomBar: true)

        return TransactionDetailsAccessoryViewModel(
            title: title,
            amount: amount,
            action: data.peerName ?? "",
            icon: icon,
            command: command,
            shouldAllowAction: true
        )
    }

    private func populateTransferAmount(
        into viewModelList: inout [WalletFormViewBindingProtocol],
        data: AssetTransactionData,
        locale: Locale
    ) {
        let title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: locale.rLanguages)

        populateAmount(
            into: &viewModelList,
            title: title,
            data: data,
            locale: locale
        )
    }

    private func populateSender(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        address: String,
        chain: Chain,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        let title = R.string.localizable
            .transactionDetailsFrom(preferredLanguages: locale.rLanguages)
        populatePeerViewModel(
            in: &viewModelList,
            title: title,
            address: address,
            chain: chain,
            commandFactory: commandFactory,
            locale: locale
        )
    }

    private func populateReceiver(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        address: String,
        chain: Chain,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        let title = R.string.localizable
            .walletSendReceiverTitle(preferredLanguages: locale.rLanguages)
        populatePeerViewModel(
            in: &viewModelList,
            title: title,
            address: address,
            chain: chain,
            commandFactory: commandFactory,
            locale: locale
        )
    }
}
