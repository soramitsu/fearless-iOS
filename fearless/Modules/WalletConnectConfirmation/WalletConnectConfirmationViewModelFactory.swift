//
//  WalletConnectConfirmationViewModelFactory.swift
//  fearless
//
//  Created by Soramitsu on 01.09.2023.
//  Copyright © 2023 Soramitsu. All rights reserved.
//

import Foundation
import UIKit
import BigInt
import SSFModels
import SSFUtils

protocol WalletConnectConfirmationViewModelFactory {
    func buildViewModel(locale: Locale) -> WalletConnectConfirmationViewModel
}

final class WalletConnectConfirmationViewModelFactoryImpl: WalletConnectConfirmationViewModelFactory {
    private typealias Row = WalletConnectConfirmationViewModel.Row

    private enum Constants {
        static let imageVerticalPosition: CGFloat = 3
        static let imageWidth: CGFloat = 6
        static let imageHeight: CGFloat = 12
        static let unlimitedAmount = BigUInt(2).power(256) - 1
    }

    private let inputData: WalletConnectConfirmationInputData
    private let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(
        inputData: WalletConnectConfirmationInputData,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    ) {
        self.inputData = inputData
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }

    func buildViewModel(locale: Locale) -> WalletConnectConfirmationViewModel {
        let request = inputData.signingRequest
        let originShadowColor = HexColorConverter.hexStringToUIColor(
            hex: request.chain.utilityAssets().first?.color
        )?.cgColor
        let symbolViewModel = SymbolViewModel(
            symbolViewModel: RemoteImageViewModel(url: request.chain.icon),
            shadowColor: originShadowColor
        )

        return WalletConnectConfirmationViewModel(
            symbolViewModel: symbolViewModel,
            method: request.method.rawValue,
            rows: buildRows(locale: locale),
            rawData: rawDataAttributed()
        )
    }

    // MARK: - Rows

    private func buildRows(locale: Locale) -> [Row] {
        let request = inputData.signingRequest
        let languages = locale.rLanguages

        var rows = [
            Row(
                kind: .network,
                title: R.string.localizable.commonNetwork(preferredLanguages: languages),
                value: request.chain.name
            )
        ]

        switch request.content {
        case let .ethereumTransaction(quote):
            rows += transactionRows(for: quote, locale: locale)
        case let .ethereumMessage(message), let .polkadotMessage(message):
            rows.append(Row(
                kind: .message,
                title: R.string.localizable.commonMessage(preferredLanguages: languages),
                value: message.displayText
            ))
            rows.append(noFeeRow(locale: locale))
        case let .ethereumTypedData(typedData):
            rows += typedDataRows(for: typedData, locale: locale)
            rows.append(noFeeRow(locale: locale))
        case let .polkadotTransaction(extrinsic):
            rows += extrinsicRows(for: extrinsic, locale: locale)
        }

        rows += accountRows(locale: locale)
        return rows
    }

    private func transactionRows(for quote: WalletConnectEthereumTransactionQuote, locale: Locale) -> [Row] {
        let chain = inputData.signingRequest.chain
        let nativeAsset = chain.utilityAssets().first
        let token = chain.assets.first { asset in
            (try? Data(hexStringSSF: asset.id)) == quote.to
        }
        let languages = locale.rLanguages

        var rows: [Row] = []
        switch quote.tokenCall {
        case let .transfer(recipient, amount):
            rows.append(recipientRow(address(of: recipient), locale: locale))
            rows.append(amountRow(formatted(amount, asset: token, locale: locale), locale: locale))
            rows.append(contractRow(quote.to, locale: locale))
        case let .transferFrom(owner, recipient, amountOrId):
            rows.append(Row(
                kind: .from,
                title: R.string.localizable.walletConnectConfirmationFrom(preferredLanguages: languages),
                value: address(of: owner)
            ))
            rows.append(recipientRow(address(of: recipient), locale: locale))
            if let token = token {
                rows.append(amountRow(formatted(amountOrId, asset: token, locale: locale), locale: locale))
            } else {
                // ERC-20 and ERC-721 share this call: an unknown contract's number may be an amount or an item.
                rows.append(Row(
                    kind: .amount,
                    title: R.string.localizable.walletConnectConfirmationAmountOrId(preferredLanguages: languages),
                    value: String(amountOrId)
                ))
            }
            rows.append(contractRow(quote.to, locale: locale))
        case let .approve(spender, amount), let .increaseAllowance(spender, amount):
            rows.append(spenderRow(address(of: spender), locale: locale))
            rows.append(amountRow(allowance(amount, asset: token, locale: locale), locale: locale))
            rows.append(contractRow(quote.to, locale: locale))
        case let .setApprovalForAll(operatorAddress, approved):
            rows.append(Row(
                kind: .spender,
                title: R.string.localizable.walletConnectConfirmationOperator(preferredLanguages: languages),
                value: address(of: operatorAddress)
            ))
            rows.append(Row(
                kind: .access,
                title: R.string.localizable.walletConnectConfirmationAccess(preferredLanguages: languages),
                value: approved
                    ? R.string.localizable.walletConnectConfirmationAccessAll(preferredLanguages: languages)
                    : R.string.localizable.walletConnectConfirmationAccessNone(preferredLanguages: languages)
            ))
            rows.append(contractRow(quote.to, locale: locale))
        case .none where quote.isUndecodedCall:
            // A contract call the wallet cannot decode: shown raw, the recipient named as the contract it is.
            rows.append(warningRow(
                R.string.localizable.walletConnectConfirmationUndecodedWarning(preferredLanguages: languages),
                locale: locale
            ))
            rows.append(contractRow(quote.to, locale: locale))
            rows.append(Row(
                kind: .function,
                title: R.string.localizable.walletConnectConfirmationFunction(preferredLanguages: languages),
                value: Data(quote.data.prefix(4)).toHex(includePrefix: true)
            ))
            rows.append(dataRow(quote.data, locale: locale))
        case .none:
            rows.append(recipientRow(address(of: quote.to), locale: locale))
        }

        if quote.trailingDataLength > 0 {
            rows.insert(
                warningRow(
                    R.string.localizable.walletConnectConfirmationTrailingWarning(preferredLanguages: languages),
                    locale: locale
                ),
                at: 0
            )
            rows.append(dataRow(quote.data, locale: locale))
        }

        // A plain transfer always shows what it sends; a contract call only when it also sends the native asset.
        let isPlainTransfer = quote.tokenCall == nil && quote.data.isEmpty
        if isPlainTransfer || quote.value > 0 {
            rows.append(amountRow(formatted(quote.value, asset: nativeAsset, locale: locale), locale: locale))
        }

        rows.append(Row(
            kind: .fee,
            title: R.string.localizable.commonNetworkFee(preferredLanguages: languages),
            value: formatted(quote.maxFee, asset: nativeAsset, locale: locale)
        ))
        return rows
    }

    private func typedDataRows(for typedData: WalletConnectTypedData, locale: Locale) -> [Row] {
        let chain = inputData.signingRequest.chain
        let languages = locale.rLanguages
        var rows: [Row] = []

        if typedData.isChainUnbound {
            rows.append(warningRow(
                R.string.localizable.walletConnectConfirmationUnboundWarning(preferredLanguages: languages),
                locale: locale
            ))
        }

        if let allowance = typedData.allowance, let amount = allowance.amount {
            let token = chain.assets.first { asset in
                (try? Data(hexStringSSF: asset.id)) == allowance.token
            }
            rows.append(spenderRow(address(of: allowance.spender), locale: locale))
            rows.append(amountRow(self.allowance(amount, asset: token, locale: locale), locale: locale))
            rows.append(contractRow(allowance.token, locale: locale))
            if let deadline = allowance.deadline {
                rows.append(Row(
                    kind: .deadline,
                    title: R.string.localizable.walletConnectConfirmationDeadline(preferredLanguages: languages),
                    value: Self.date(deadline, locale: locale)
                ))
            }
        } else {
            // Typed data the wallet does not specifically understand: every signed field is shown.
            rows.append(warningRow(
                R.string.localizable.walletConnectConfirmationTypedWarning(preferredLanguages: languages),
                locale: locale
            ))
            if let allowance = typedData.allowance {
                rows.append(spenderRow(address(of: allowance.spender), locale: locale))
                rows.append(amountRow(
                    R.string.localizable.walletConnectConfirmationUnreadable(preferredLanguages: languages),
                    locale: locale
                ))
            }
            if let verifyingContract = typedData.verifyingContract {
                rows.append(contractRow(verifyingContract, locale: locale))
            }
            rows += typedData.fields.map { Row(kind: .field, title: $0.path, value: $0.value) }
        }

        let summary = [typedData.domainName, typedData.primaryType]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        rows.append(Row(
            kind: .message,
            title: R.string.localizable.commonMessage(preferredLanguages: languages),
            value: summary
        ))
        return rows
    }

    private func extrinsicRows(for extrinsic: WalletConnectPolkadotExtrinsic, locale: Locale) -> [Row] {
        let utilityAsset = inputData.signingRequest.chain.utilityAssets().first
        let languages = locale.rLanguages
        var rows: [Row] = []

        if let transfer = extrinsic.transfer {
            rows.append(recipientRow(address(of: transfer.recipient), locale: locale))
            rows.append(amountRow(formatted(transfer.amount, asset: utilityAsset, locale: locale), locale: locale))
            rows.append(Row(
                kind: .call,
                title: R.string.localizable.walletConnectConfirmationCall(preferredLanguages: languages),
                value: "\(extrinsic.call.moduleName).\(extrinsic.call.callName)"
            ))
        } else {
            // Any other call is shown as the runtime decodes it, nested calls included, with a warning.
            rows.append(warningRow(
                R.string.localizable.walletConnectConfirmationCallWarning(preferredLanguages: languages),
                locale: locale
            ))
            let callText = WalletConnectSubstrateCallText(
                address: { [weak self] accountId in self?.address(of: accountId) },
                nativeAmount: { [weak self] amount in self?.formatted(amount, asset: utilityAsset, locale: locale) }
            )
            rows += callText.rows(for: extrinsic.call, locale: locale)
        }

        rows.append(Row(
            kind: .fee,
            title: R.string.localizable.commonNetworkFee(preferredLanguages: languages),
            value: formatted(extrinsic.fee, asset: utilityAsset, locale: locale)
        ))

        if extrinsic.tip > 0 {
            rows.append(Row(
                kind: .tip,
                title: R.string.localizable.walletConnectConfirmationTip(preferredLanguages: languages),
                value: formatted(extrinsic.tip, asset: utilityAsset, locale: locale)
            ))
        }
        return rows
    }

    private func accountRows(locale: Locale) -> [Row] {
        let request = inputData.signingRequest
        let session = inputData.session
        let languages = locale.rLanguages
        // The site WalletConnect Verify saw the request come from, when it is not the one the app claims.
        let host = inputData.verification.website(claimed: session.peer.url)

        return [
            Row(
                kind: .wallet,
                title: R.string.localizable.commonWallet(preferredLanguages: languages),
                value: request.wallet.name
            ),
            Row(
                kind: .account,
                title: R.string.localizable.commonAccount(preferredLanguages: languages),
                value: address(of: request.account.accountId)
            ),
            Row(
                kind: .app,
                title: R.string.localizable.walletConnectConfirmationApp(preferredLanguages: languages),
                value: session.peer.name
            ),
            Row(
                kind: .website,
                title: R.string.localizable.walletConnectConfirmationWebsite(preferredLanguages: languages),
                value: host
            ),
            Row(
                kind: .verification,
                title: R.string.localizable.walletConnectVerifyTitle(preferredLanguages: languages),
                value: inputData.verification.title(for: locale)
            )
        ]
    }

    // MARK: - Row helpers

    private func recipientRow(_ value: String, locale: Locale) -> Row {
        Row(
            kind: .recipient,
            title: R.string.localizable.walletConnectConfirmationRecipient(preferredLanguages: locale.rLanguages),
            value: value
        )
    }

    private func spenderRow(_ value: String, locale: Locale) -> Row {
        Row(
            kind: .spender,
            title: R.string.localizable.walletConnectConfirmationSpender(preferredLanguages: locale.rLanguages),
            value: value
        )
    }

    private func amountRow(_ value: String, locale: Locale) -> Row {
        Row(
            kind: .amount,
            title: R.string.localizable.walletConnectConfirmationAmount(preferredLanguages: locale.rLanguages),
            value: value
        )
    }

    private func contractRow(_ contract: Data, locale: Locale) -> Row {
        Row(
            kind: .contract,
            title: R.string.localizable.walletConnectConfirmationContract(preferredLanguages: locale.rLanguages),
            value: contract.toHex(includePrefix: true)
        )
    }

    private func warningRow(_ text: String, locale: Locale) -> Row {
        Row(
            kind: .warning,
            title: R.string.localizable.commonWarning(preferredLanguages: locale.rLanguages),
            value: text
        )
    }

    /// Raw transaction data: the first 256 bytes, then how many more there are; the raw-data view has it all.
    private func dataRow(_ data: Data, locale: Locale) -> Row {
        let shown = Data(data.prefix(256)).toHex(includePrefix: true)
        let value = data.count > 256 ? "\(shown)… (\(data.count) bytes)" : shown
        return Row(
            kind: .data,
            title: R.string.localizable.walletConnectConfirmationData(preferredLanguages: locale.rLanguages),
            value: value
        )
    }

    /// A Unix time as a date, or the number itself when it is beyond any date (some permits never expire).
    static func date(_ seconds: BigUInt, locale: Locale) -> String {
        guard seconds <= BigUInt(253_402_300_799), let value = Double(String(seconds)) else {
            return String(seconds)
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date(timeIntervalSince1970: value))
    }

    private func noFeeRow(locale: Locale) -> Row {
        let languages = locale.rLanguages
        return Row(
            kind: .fee,
            title: R.string.localizable.commonNetworkFee(preferredLanguages: languages),
            value: R.string.localizable.walletConnectConfirmationNoFee(preferredLanguages: languages)
        )
    }

    // MARK: - Formatting

    private func address(of accountId: AccountId) -> String {
        let chain = inputData.signingRequest.chain
        return (try? AddressFactory.address(for: accountId, chain: chain)) ?? accountId.toHex(includePrefix: true)
    }

    /// The exact amount, with every significant digit, in the asset's units.
    private func formatted(_ amount: BigUInt, asset: AssetModel?, locale: Locale) -> String {
        guard
            let asset = asset,
            let decimal = Decimal.fromSubstrateAmount(amount, precision: Int16(bitPattern: asset.precision))
        else {
            return String(amount)
        }

        let formatter = assetBalanceFormatterFactory.createTokenFormatter(
            for: asset.displayInfo,
            usageCase: .exactCrypto(fractionDigits: Int(asset.precision))
        )
        return formatter.value(for: locale).stringFromDecimal(decimal) ?? String(amount)
    }

    private func allowance(_ amount: BigUInt, asset: AssetModel?, locale: Locale) -> String {
        guard amount < Constants.unlimitedAmount else {
            return R.string.localizable.walletConnectConfirmationUnlimited(preferredLanguages: locale.rLanguages)
        }
        return formatted(amount, asset: asset, locale: locale)
    }

    private func rawDataAttributed() -> NSAttributedString {
        let rawDataAttributed = NSMutableAttributedString(string: "")
        let imageAttachment = NSTextAttachment()
        imageAttachment.bounds = CGRect(
            x: 0,
            y: -Constants.imageVerticalPosition,
            width: Constants.imageWidth,
            height: Constants.imageHeight
        )
        if let iconAboutArrowImage = R.image.dropTriangle() {
            imageAttachment.image = iconAboutArrowImage.rotate(radians: .pi / -2)
        }

        let imageString = NSAttributedString(attachment: imageAttachment)
        rawDataAttributed.append(imageString)

        return rawDataAttributed
    }
}
