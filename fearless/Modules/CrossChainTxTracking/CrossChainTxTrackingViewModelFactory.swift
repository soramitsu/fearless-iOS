import Foundation
import SSFModels
import BigInt

protocol CrossChainTxTrackingViewModelFactory {
    func buildViewModel(
        transaction: AssetTransactionData,
        status: OKXCrossChainTransactionStatus,
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        locale: Locale,
        wallet: MetaAccountModel
    ) -> CrossChainTxTrackingViewModel
}

final class CrossChainTxTrackingViewModelFactoryImpl: CrossChainTxTrackingViewModelFactory {
    func buildViewModel(
        transaction: AssetTransactionData,
        status: OKXCrossChainTransactionStatus,
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset,
        locale: Locale,
        wallet: MetaAccountModel
    ) -> CrossChainTxTrackingViewModel {
        let date = DateFormatter.crossChainDate.value(for: locale).string(from: Date(timeIntervalSince1970: TimeInterval(transaction.timestamp)))

        let sourceBalanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: sourceChainAsset)

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

        let destinationUtilityChainAsset = destinationChainAsset.chain.utilityChainAssets().first
        let destinationUtilityBalanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: destinationUtilityChainAsset)
        let destinationFee = Decimal(string: status.sourceChainGasfee)
        let destinationFeeViewModel = destinationFee.flatMap { destinationUtilityBalanceViewModelFactory?.balanceFromPrice($0, priceData: destinationUtilityChainAsset?.asset.getPrice(for: wallet.selectedCurrency), usageCase: .detailsCrypto) }
        let statusTitle = statusTitle(status: status, locale: locale)
        let statusDescription = statusDescription(
            status: status,
            locale: locale,
            sourceChainAsset: sourceChainAsset,
            destinationChainAsset: destinationChainAsset
        )
        let statusViewModels = buildStatusViewModels(
            sourceChainAsset: sourceChainAsset,
            destinationChainAsset: destinationChainAsset,
            status: status
        )

        return CrossChainTxTrackingViewModel(
            statusViewModels: statusViewModels,
            statusTitle: statusTitle,
            statusDescription: statusDescription,
            walletName: transaction.peerFirstName,
            date: date,
            amount: amountViewModel?.value(for: locale),
            fromChainTxHash: status.fromTxHash,
            toChainTxHash: status.toTxHash,
            fromChainFee: sourceFeeViewModel?.value(for: locale),
            toChainFee: destinationFeeViewModel?.value(for: locale),
            detailStatus: status.detailStatus,
            fromHashViewTitle: R.string.localizable.commonNetworkHash(sourceChainAsset.chain.name, preferredLanguages: locale.rLanguages),
            toHashViewTitle: R.string.localizable.commonNetworkHash(destinationChainAsset.chain.name, preferredLanguages: locale.rLanguages),
            fromFeeViewTitle: R.string.localizable.xcmOriginNetworkFeeTitle(preferredLanguages: locale.rLanguages),
            toFeeViewTitle: R.string.localizable.xcmDestinationNetworkFeeTitle(preferredLanguages: locale.rLanguages)
        )
    }

    private func statusTitle(status: OKXCrossChainTransactionStatus, locale: Locale) -> String? {
        guard let detailStatus = OKXCrossChainTxDetailStatus(rawValue: status.detailStatus) else {
            return nil
        }
        switch detailStatus {
        case .waiting, .fromSuccess, .bridgePending:
            return R.string.localizable.crossChainTxStatusPendingTitle(preferredLanguages: locale.rLanguages)
        case .fromFailure:
            return R.string.localizable.crossChainTxStatusSourceFailTitle(preferredLanguages: locale.rLanguages)
        case .bridgeSuccess, .success:
            return R.string.localizable.crossChainTxStatusDoneTitle(preferredLanguages: locale.rLanguages)
        case .refund:
            return R.string.localizable.commonRefund(preferredLanguages: locale.rLanguages)
        }
    }

    private func statusDescription(
        status: OKXCrossChainTransactionStatus,
        locale: Locale,
        sourceChainAsset: ChainAsset,
        destinationChainAsset: ChainAsset
    ) -> String? {
        guard let detailStatus = OKXCrossChainTxDetailStatus(rawValue: status.detailStatus) else {
            return nil
        }

        switch detailStatus {
        case .waiting, .fromSuccess, .bridgePending:
            return R.string.localizable.crossChainTxStatusPendingDescription(sourceChainAsset.asset.symbol.uppercased(), sourceChainAsset.chain.name, destinationChainAsset.chain.name, preferredLanguages: locale.rLanguages)
        case .fromFailure:
            return R.string.localizable.crossChainTxStatusSourceFailDescription(sourceChainAsset.chain.name, preferredLanguages: locale.rLanguages)
        case .bridgeSuccess, .success:
            return R.string.localizable.crossChainTxStatusDoneDescription(preferredLanguages: locale.rLanguages)
        case .refund:
            return R.string.localizable.crossChainTxStatusDestinationFailDescription(destinationChainAsset.chain.name, preferredLanguages: locale.rLanguages)
        }
    }

    private func buildStatusViewModels(sourceChainAsset: ChainAsset, destinationChainAsset: ChainAsset, status: OKXCrossChainTransactionStatus) -> [Any] {
        guard let detailStatus = OKXCrossChainTxDetailStatus(rawValue: status.detailStatus) else {
            return []
        }

        let sourceStepStatus = buildSourceStepStatus(status: detailStatus)
        let sourceChainStepViewModel = CrossChainTransactionStepViewModel(status: sourceStepStatus, chain: sourceChainAsset.chain, parentChain: nil)

        let destinationStepStatus = buildDestinationStepStatus(status: detailStatus)
        let destinationChainStepViewModel = CrossChainTransactionStepViewModel(status: destinationStepStatus, chain: destinationChainAsset.chain, parentChain: nil)
        let destinationViewModel = CrossChainTransactionStatusViewModel(status: destinationStepStatus)

        return [sourceChainStepViewModel, destinationViewModel, destinationChainStepViewModel]
    }

    private func buildSourceStepStatus(status: OKXCrossChainTxDetailStatus) -> CrossChainStepStatus {
        switch status {
        case .waiting:
            return .pending
        case .fromSuccess:
            return .success
        case .fromFailure:
            return .failed
        case .bridgePending:
            return .success
        case .bridgeSuccess:
            return .success
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
            return .success
        case .success:
            return .success
        case .refund:
            return .refund
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
