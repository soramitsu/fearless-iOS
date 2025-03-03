import Foundation
import SoraFoundation
import SSFModels
import BigInt

protocol CrossChainTxTrackingViewModelFactory {
    func buildCrossChainViewModel(
        transaction: AssetTransactionData,
        status: OKXCrossChainTransactionStatus,
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        locale: Locale,
        wallet: MetaAccountModel,
        destinationChainAssets:[ChainAsset]
    ) -> CrossChainTxTrackingViewModel

    func buildFailureViewModel(
        transaction: AssetTransactionData,
        status: OKXCrossChainTransactionStatus,
        sourceChainAsset: ChainAsset,
        locale: Locale,
        wallet: MetaAccountModel
    ) -> CrossChainTxTrackingViewModel

    func buildSwapViewModel(
        transaction: AssetTransactionData,
        status: OKXSwapTransactionHistoryDetails,
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset?,
        locale: Locale,
        wallet: MetaAccountModel
    ) -> CrossChainTxTrackingViewModel
}

final class CrossChainTxTrackingViewModelFactoryImpl: CrossChainTxTrackingViewModelFactory {
    func buildSwapViewModel(
        transaction: AssetTransactionData,
        status: OKXSwapTransactionHistoryDetails,
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset?,
        locale: Locale,
        wallet: MetaAccountModel
    ) -> CrossChainTxTrackingViewModel {
        let sourceBalanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: sourceChainAsset)
        let destinationBalanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: destinationChainAsset)

        let date = DateFormatter.crossChainDate.value(for: locale).string(from: Date(timeIntervalSince1970: TimeInterval(transaction.timestamp)))
        let statusViewModels = buildSwapStatusViewModels(
            chainAsset: sourceChainAsset,
            tx: status
        )

        let sourceUtilityChainAsset = sourceChainAsset.chain.utilityChainAssets().first
        let sourceUtilityBalanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: sourceUtilityChainAsset)
        let sourceFee = status.txFee.flatMap { Decimal(string: $0) }
        let sourceFeeViewModel = sourceFee.flatMap { sourceUtilityBalanceViewModelFactory?.balanceFromPrice($0, priceData: sourceUtilityChainAsset?.asset.getPrice(for: wallet.selectedCurrency), usageCase: .detailsCrypto) }

        let amountDecimal = transaction.amount
        let amountViewModel = sourceBalanceViewModelFactory?.balanceFromPrice(
            amountDecimal.decimalValue,
            priceData: sourceChainAsset.asset.getPrice(for: wallet.selectedCurrency),
            usageCase: .detailsCrypto
        )
        
        
        let destinationAmount = destinationChainAsset.flatMap { asset in
            return status.toTokenDetails?.amount.flatMap { amountString in
                BigUInt(string: amountString) }.flatMap { amount in
                    Decimal.fromSubstrateAmount(amount, precision: Int16(asset.asset.precision))
                }
        }
        
        let destinationAmountViewModel = destinationAmount.flatMap {
            destinationBalanceViewModelFactory?.balanceFromPrice(
                $0,
                priceData: destinationChainAsset?.asset.getPrice(for: wallet.selectedCurrency),
                usageCase: .detailsCrypto
            )
        }
        
        let address = wallet.fetch(for: sourceChainAsset.chain.accountRequest())?.toAddress()

        let statusTitle = statusTitle(detailStatus: status.swapDetailStatus, locale: locale)
        let statusDescription = statusDescription(
            detailStatus: status.swapDetailStatus,
            locale: locale,
            sourceChainAsset: sourceChainAsset,
            destinationChainAsset: sourceChainAsset
        )

        let crossChainStatus = status.status.flatMap { OKXCrossChainTxStatus(rawValue: $0.uppercased()) }
        let detailStatus = status.swapDetailStatus
        let statusViewModel = buildStatusViewModel(
            status: crossChainStatus,
            detailStatus: detailStatus,
            locale: locale
        )

        return CrossChainTxTrackingViewModel(
            statusViewModels: statusViewModels,
            statusTitle: statusTitle,
            statusDescription: statusDescription,
            walletName: address,
            date: date,
            amount: amountViewModel?.value(for: locale),
            receivedAmount: destinationAmountViewModel?.value(for: locale),
            fromChainTxHash: status.txHash,
            toChainTxHash: nil,
            fromChainFee: sourceFeeViewModel?.value(for: locale),
            toChainFee: nil,
            detailStatus: statusTitle,
            fromHashViewTitle: R.string.localizable.commonNetworkHash(sourceChainAsset.chain.name, preferredLanguages: locale.rLanguages),
            toHashViewTitle: nil,
            fromFeeViewTitle: R.string.localizable.xcmOriginNetworkFeeTitle(preferredLanguages: locale.rLanguages),
            toFeeViewTitle: R.string.localizable.xcmDestinationNetworkFeeTitle(preferredLanguages: locale.rLanguages),
            statusViewModel: statusViewModel
        )
    }

    func buildFailureViewModel(
        transaction: AssetTransactionData,
        status: OKXCrossChainTransactionStatus,
        sourceChainAsset: ChainAsset,
        locale: Locale,
        wallet: MetaAccountModel
    ) -> CrossChainTxTrackingViewModel {
        let sourceBalanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: sourceChainAsset)
        let date = DateFormatter.crossChainDate.value(for: locale).string(from: Date(timeIntervalSince1970: TimeInterval(transaction.timestamp)))
        let sourceStepStatus = buildSourceStepStatus(status: .fromFailure)
        let sourceUtilityChainAsset = sourceChainAsset.chain.utilityChainAssets().first
        let sourceUtilityBalanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: sourceUtilityChainAsset)
        let sourceFee = Decimal(string: status.sourceChainGasfee)
        let sourceFeeViewModel = sourceFee.flatMap { sourceUtilityBalanceViewModelFactory?.balanceFromPrice($0, priceData: sourceUtilityChainAsset?.asset.getPrice(for: wallet.selectedCurrency), usageCase: .detailsCrypto) }
        let amountDecimal = transaction.amount
        let amountViewModel = sourceBalanceViewModelFactory?.balanceFromPrice(
            amountDecimal.decimalValue,
            priceData: sourceChainAsset.asset.getPrice(for: wallet.selectedCurrency),
            usageCase: .detailsCrypto
        )
        let address = wallet.fetch(for: sourceChainAsset.chain.accountRequest())?.toAddress()
        let crossChainStatus = OKXCrossChainTxStatus(rawValue: status.status)
        let detailStatus = status.swapDetailStatus
        let statusViewModel = buildStatusViewModel(
            status: crossChainStatus,
            detailStatus: detailStatus,
            locale: locale
        )

        return CrossChainTxTrackingViewModel(
            statusViewModels: [sourceStepStatus],
            statusTitle: R.string.localizable.crossChainTxStatusSourceFailTitle(preferredLanguages: locale.rLanguages),
            statusDescription: R.string.localizable.crossChainTxStatusSourceFailDescription(sourceChainAsset.chain.name, preferredLanguages: locale.rLanguages),
            walletName: address,
            date: date,
            amount: amountViewModel?.value(for: locale),
            receivedAmount: nil,
            fromChainTxHash: status.fromTxHash,
            toChainTxHash: status.toTxHash,
            fromChainFee: sourceFeeViewModel?.value(for: locale),
            toChainFee: nil,
            detailStatus: status.detailStatus,
            fromHashViewTitle: R.string.localizable.commonNetworkHash(sourceChainAsset.chain.name, preferredLanguages: locale.rLanguages),
            toHashViewTitle: nil,
            fromFeeViewTitle: R.string.localizable.xcmOriginNetworkFeeTitle(preferredLanguages: locale.rLanguages),
            toFeeViewTitle: R.string.localizable.xcmDestinationNetworkFeeTitle(preferredLanguages: locale.rLanguages),
            statusViewModel: statusViewModel
        )
    }

    func buildCrossChainViewModel(
        transaction: AssetTransactionData,
        status: OKXCrossChainTransactionStatus,
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        locale: Locale,
        wallet: MetaAccountModel,
        destinationChainAssets: [ChainAsset]
    ) -> CrossChainTxTrackingViewModel {
        let receivedChainAsset = destinationChainAssets.first(where: { $0.asset.id.lowercased() == status.refundTokenAddress?.lowercased() }) ?? destinationChainAsset

        let date = DateFormatter.crossChainDate.value(for: locale).string(from: Date(timeIntervalSince1970: TimeInterval(transaction.timestamp)))

        let sourceBalanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: sourceChainAsset)
        let destinationBalanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: receivedChainAsset)

        let toAmountValue = BigUInt(string: status.toAmount)
        let toAmountViewModel: LocalizableResource<BalanceViewModelProtocol>? = toAmountValue.flatMap {
            let toAmountDecimal = Decimal.fromSubstrateAmount($0, precision: Int16(receivedChainAsset.asset.precision))

            guard let toAmountDecimal, toAmountDecimal > 0 else {
                return nil
            }

            return destinationBalanceViewModelFactory?.balanceFromPrice(
                toAmountDecimal,
                priceData: receivedChainAsset.asset.getPrice(for: wallet.selectedCurrency),
                usageCase: .detailsCrypto
            )
        }

        let amountValue = BigUInt(string: status.fromAmount)
        let amountDecimal = Decimal.fromSubstrateAmount(amountValue.or(.zero), precision: Int16(sourceChainAsset.asset.precision))

        let amountViewModel = sourceBalanceViewModelFactory?.balanceFromPrice(
            amountDecimal.or(.zero),
            priceData: sourceChainAsset.asset.getPrice(for: wallet.selectedCurrency),
            usageCase: .detailsCrypto
        )

        let sourceUtilityChainAsset = sourceChainAsset.chain.utilityChainAssets().first
        let sourceUtilityBalanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: sourceUtilityChainAsset)
        let sourceFee = Decimal(string: status.sourceChainGasfee)
        let sourceFeeViewModel = sourceFee.flatMap { sourceUtilityBalanceViewModelFactory?.balanceFromPrice($0, priceData: sourceUtilityChainAsset?.asset.getPrice(for: wallet.selectedCurrency), usageCase: .detailsCrypto) }

        let destinationUtilityChainAsset = receivedChainAsset.chain.utilityChainAssets().first
        let destinationUtilityBalanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: receivedChainAsset)
        let destinationFee = Decimal(string: status.sourceChainGasfee)
        let destinationFeeViewModel = destinationFee.flatMap { destinationUtilityBalanceViewModelFactory?.balanceFromPrice($0, priceData: destinationUtilityChainAsset?.asset.getPrice(for: wallet.selectedCurrency), usageCase: .detailsCrypto) }
        let detailStatus = OKXCrossChainTxDetailStatus(rawValue: status.detailStatus) ?? .fromFailure
        let statusTitle = statusTitle(detailStatus: detailStatus, locale: locale)
        let statusDescription = statusDescription(
            detailStatus: detailStatus,
            locale: locale,
            sourceChainAsset: sourceChainAsset,
            destinationChainAsset: receivedChainAsset
        )

        let statusViewModels = buildStatusViewModels(
            sourceChainAsset: sourceChainAsset,
            destinationChainAsset: receivedChainAsset,
            status: detailStatus
        )
        let address = wallet.fetch(for: sourceChainAsset.chain.accountRequest())?.toAddress()
        let crossChainStatus = OKXCrossChainTxStatus(rawValue: status.status)
        let statusViewModel = buildStatusViewModel(
            status: crossChainStatus,
            detailStatus: detailStatus,
            locale: locale
        )
        
        return CrossChainTxTrackingViewModel(
            statusViewModels: statusViewModels,
            statusTitle: statusTitle,
            statusDescription: statusDescription,
            walletName: address,
            date: date,
            amount: amountViewModel?.value(for: locale),
            receivedAmount: toAmountViewModel?.value(for: locale),
            fromChainTxHash: status.fromTxHash,
            toChainTxHash: status.toTxHash,
            fromChainFee: sourceFeeViewModel?.value(for: locale),
            toChainFee: destinationFeeViewModel?.value(for: locale),
            detailStatus: status.detailStatus,
            fromHashViewTitle: R.string.localizable.commonNetworkHash(sourceChainAsset.chain.name, preferredLanguages: locale.rLanguages),
            toHashViewTitle: R.string.localizable.commonNetworkHash(receivedChainAsset.chain.name, preferredLanguages: locale.rLanguages),
            fromFeeViewTitle: R.string.localizable.xcmOriginNetworkFeeTitle(preferredLanguages: locale.rLanguages),
            toFeeViewTitle: R.string.localizable.xcmDestinationNetworkFeeTitle(preferredLanguages: locale.rLanguages),
            statusViewModel: statusViewModel
        )
    }
    
    private func buildStatusViewModel(
        status: OKXCrossChainTxStatus?,
        detailStatus: OKXCrossChainTxDetailStatus,
        locale: Locale
    ) -> CrossChainStatusViewModel {
        return CrossChainStatusViewModel(status: status, detailStatus: detailStatus, locale: locale)
    }

    private func statusTitle(detailStatus: OKXCrossChainTxDetailStatus, locale: Locale) -> String? {
        switch detailStatus {
        case .waiting, .fromSuccess, .bridgePending, .notFound, .bridgeSuccess:
            return R.string.localizable.crossChainTxStatusPendingTitle(preferredLanguages: locale.rLanguages)
        case .fromFailure:
            return R.string.localizable.crossChainTxStatusSourceFailTitle(preferredLanguages: locale.rLanguages)
        case .success:
            return R.string.localizable.crossChainTxStatusDoneTitle(preferredLanguages: locale.rLanguages)
        case .refund:
            return R.string.localizable.commonRefund(preferredLanguages: locale.rLanguages)
        }
    }

    private func statusDescription(
        detailStatus: OKXCrossChainTxDetailStatus,
        locale: Locale,
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset
    ) -> String? {
        switch detailStatus {
        case .notFound:
            return nil
        case .waiting, .fromSuccess, .bridgePending, .bridgeSuccess:
            return R.string.localizable.crossChainTxStatusPendingDescription(sourceChainAsset.asset.symbol.uppercased(), sourceChainAsset.chain.name, destinationChainAsset.chain.name, preferredLanguages: locale.rLanguages)
        case .fromFailure:
            return R.string.localizable.crossChainTxStatusSourceFailDescription(sourceChainAsset.chain.name, preferredLanguages: locale.rLanguages)
        case .success:
            return R.string.localizable.crossChainTxStatusDoneDescription(preferredLanguages: locale.rLanguages)
        case .refund:
            return R.string.localizable.crossChainTxStatusDestinationFailDescription(destinationChainAsset.chain.name, preferredLanguages: locale.rLanguages)
        }
    }

    private func buildSwapStatusViewModels(chainAsset: ChainAsset, tx: OKXSwapTransactionHistoryDetails) -> [Any] {
        let status = tx.status.flatMap { OKXCrossChainTxDetailStatus(txDetailStatus: $0) }
        
        guard let status else {
            return []
        }
        
        let sourceStepStatus = buildSourceStepStatus(status: status)
        let sourceChainStepViewModel = CrossChainTransactionStepViewModel(status: sourceStepStatus, chain: chainAsset.chain, parentChain: nil)

        return [sourceChainStepViewModel]
    }

    private func buildStatusViewModels(sourceChainAsset: ChainAsset, destinationChainAsset: ChainAsset, status: OKXCrossChainTxDetailStatus) -> [Any] {
        let sourceStepStatus = buildSourceStepStatus(status: status)
        let sourceChainStepViewModel = CrossChainTransactionStepViewModel(status: sourceStepStatus, chain: sourceChainAsset.chain, parentChain: nil)

        let destinationStepStatus = buildDestinationStepStatus(status: status)
        let destinationChainStepViewModel = CrossChainTransactionStepViewModel(status: destinationStepStatus, chain: destinationChainAsset.chain, parentChain: nil)
        let destinationViewModel = CrossChainTransactionStatusViewModel(status: destinationStepStatus)

        return [sourceChainStepViewModel, destinationViewModel, destinationChainStepViewModel]
    }

    private func buildSourceStepStatus(status: OKXCrossChainTxDetailStatus) -> CrossChainStepStatus {
        switch status {
        case .waiting, .notFound:
            return .pending
        case .fromSuccess:
            return .success
        case .fromFailure:
            return .failed
        case .bridgePending:
            return .success
        case .bridgeSuccess:
            return .pending
        case .success:
            return .success
        case .refund:
            return .success
        }
    }

    private func buildDestinationStepStatus(status: OKXCrossChainTxDetailStatus) -> CrossChainStepStatus {
        switch status {
        case .waiting:
            return .pending
        case .fromSuccess:
            return .pending
        case .fromFailure:
            return .pending
        case .bridgePending:
            return .pending
        case .bridgeSuccess:
            return .pending
        case .success:
            return .success
        case .refund:
            return .refund
        case .notFound:
            return .pending
        }
    }

    private func buildBalanceViewModelFactory(
        wallet: MetaAccountModel,
        for chainAsset: ChainAsset?
    ) -> BalanceViewModelFactoryProtocol? {
        guard let chainAsset = chainAsset else {
            return nil
        }
        let assetInfo = chainAsset.asset
            .displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet,
            chainAsset: chainAsset
        )
        return balanceViewModelFactory
    }
}
