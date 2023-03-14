import Foundation
import CommonWallet

protocol SwapTransactionViewModelFactoryProtocol {
    func createViewModel(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        transaction: AssetTransactionData,
        priceData: PriceData?,
        locale: Locale
    ) -> SwapTransactionViewModel
}

final class SwapTransactionViewModelFactory: SwapTransactionViewModelFactoryProtocol {
    private enum Constants {
        static let imageWidth: CGFloat = 8
        static let imageHeight: CGFloat = 14
        static let imageVerticalPosition: CGFloat = 6
    }

    func createViewModel(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        transaction: AssetTransactionData,
        priceData: PriceData?,
        locale: Locale
    ) -> SwapTransactionViewModel {
        let sendAsset = chainAsset.chain.chainAssets.first(where: {
            $0.asset.currencyId == transaction.peerId
        })
        let receiveAsset = chainAsset.chain.chainAssets.first {
            $0.asset.currencyId == transaction.assetId
        }

        let doubleImageViewViewModel = createDoubleImageViewModel(
            fromChainAsset: sendAsset,
            toChainAsset: receiveAsset
        )

        let amountsText = buildAmountsText(
            fromAmount: AmountDecimal(string: transaction.details)?.decimalValue ?? .zero,
            toAmount: transaction.amount.decimalValue,
            fromChainAsset: sendAsset,
            toChainAsset: receiveAsset,
            locale: locale
        )

        let status = createStatusAttributedString(
            transaction: transaction,
            locale: locale
        )

        let address = createAddress(wallet: wallet, chainAsset: chainAsset)

        let date = Date(timeIntervalSince1970: TimeInterval(transaction.timestamp))
        let dateString = DateFormatter.txDetails.value(for: locale).string(from: date)

        let networkFee = createNetworkFeeViewModel(
            wallet: wallet,
            chainAsset: chainAsset,
            transaction: transaction,
            priceData: priceData,
            locale: locale
        )

        return SwapTransactionViewModel(
            doubleImageViewViewModel: doubleImageViewViewModel,
            amountsText: amountsText,
            status: status,
            walletName: wallet.name,
            address: address,
            date: dateString,
            networkFee: networkFee
        )
    }

    // MARK: - Private methods

    private func createDoubleImageViewModel(
        fromChainAsset: ChainAsset?,
        toChainAsset: ChainAsset?
    ) -> PolkaswapDoubleSymbolViewModel {
        let leftColor = HexColorConverter.hexStringToUIColor(hex: fromChainAsset?.asset.color)?.cgColor
        let rightColor = HexColorConverter.hexStringToUIColor(hex: toChainAsset?.asset.color)?.cgColor
        let doubleImageViewViewModel = PolkaswapDoubleSymbolViewModel(
            leftViewModel: fromChainAsset?.asset.icon.map { RemoteImageViewModel(url: $0) },
            rightViewModel: toChainAsset?.asset.icon.map { RemoteImageViewModel(url: $0) },
            leftShadowColor: leftColor,
            rightShadowColor: rightColor
        )
        return doubleImageViewViewModel
    }

    private func buildAmountsText(
        fromAmount: Decimal,
        toAmount: Decimal,
        fromChainAsset: ChainAsset?,
        toChainAsset: ChainAsset?,
        locale: Locale
    ) -> NSMutableAttributedString {
        let fromAmount = fromAmount.toString(locale: locale, digits: 4)
        let fromName = fromChainAsset?.asset.name
        let leftText = [fromAmount, fromName]
            .compactMap { $0 }
            .joined(separator: " ")

        let rightAmount = toAmount.toString(locale: locale, digits: 4)
        let rightName = toChainAsset?.asset.name
        let rightText = [rightAmount, rightName]
            .compactMap { $0 }
            .joined(separator: " ")

        let amountsTitle = insertArrow(in: [leftText, rightText])
        return amountsTitle
    }

    private func createStatusAttributedString(
        transaction: AssetTransactionData,
        locale: Locale
    ) -> NSMutableAttributedString {
        let statusString: String
        let statusColor: UIColor
        switch transaction.status {
        case .pending:
            statusString = transaction.status.rawValue
            statusColor = R.color.colorOrange()!
        case .commited:
            statusString = R.string.localizable
                .polkaswapConfirmationSwappedStub(preferredLanguages: locale.rLanguages)
            statusColor = R.color.colorGreen()!
        case .rejected:
            statusString = transaction.status.rawValue
            statusColor = R.color.colorRed()!
        }

        let attributedString = NSMutableAttributedString(string: statusString)
        attributedString.addAttributes(
            [NSAttributedString.Key.foregroundColor: statusColor],
            range: NSRange(
                location: 0,
                length: statusString.count
            )
        )

        return attributedString
    }

    private func createAddress(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) -> String {
        let request = chainAsset.chain.accountRequest()
        guard let accountId = wallet.fetch(for: request)?.accountId else {
            return ""
        }
        let address = try? AddressFactory.address(for: accountId, chain: chainAsset.chain)
        return address ?? ""
    }

    private func createNetworkFeeViewModel(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        transaction: AssetTransactionData,
        priceData: PriceData?,
        locale: Locale
    ) -> BalanceViewModelProtocol {
        let xorChainAsset = chainAsset.chain.utilityChainAssets().first

        let totalFee = transaction.fees.reduce(Decimal(0)) { result, item in
            if item.assetId == transaction.assetId {
                return result + item.amount.decimalValue
            } else {
                return result
            }
        }

        let balanceViewModelFactory = createBalanceViewModelFactory(wallet: wallet, for: xorChainAsset ?? chainAsset)
        let feeViewModel = balanceViewModelFactory.balanceFromPrice(
            totalFee,
            priceData: priceData,
            isApproximately: true
        ).value(for: locale)

        return feeViewModel
    }

    private func createBalanceViewModelFactory(
        wallet: MetaAccountModel,
        for chainAsset: ChainAsset
    ) -> BalanceViewModelFactory {
        let assetInfo = chainAsset.asset.displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet
        )
        return balanceViewModelFactory
    }

    private func insertArrow(in texts: [String]) -> NSMutableAttributedString {
        let attributedString = NSMutableAttributedString()

        texts.enumerated().forEach { index, text in
            attributedString.append(NSAttributedString(string: text))
            if index % 2 == 0 {
                let imageAttachment = NSTextAttachment()
                imageAttachment.image = R.image.iconSmallArrow()
                imageAttachment.bounds = CGRect(
                    x: 0,
                    y: -Constants.imageVerticalPosition,
                    width: imageAttachment.image?.size.width ?? Constants.imageWidth,
                    height: imageAttachment.image?.size.height ?? Constants.imageHeight
                )

                let imageString = NSAttributedString(attachment: imageAttachment)
                attributedString.append(imageString)
                attributedString.append(NSAttributedString(string: "  "))
            }
        }

        return attributedString
    }
}
