import Foundation
import Web3
import BigInt
import SoraFoundation
import IrohaCrypto
import SwiftUI
import SSFModels
import UIKit

struct TonUnknownOutcomeRecoveryModel: Equatable {
    let messageHashHex: String

    init?(messageHashHex: String) {
        guard messageHashHex.utf8.count == 64,
              messageHashHex.utf8.allSatisfy({ byte in
                  (48 ... 57).contains(byte) || (97 ... 102).contains(byte)
              })
        else {
            return nil
        }
        self.messageHashHex = messageHashHex
    }
}

/// A Bitcoin transaction ID as the wallet computed it. Only the exact 64 lowercase hex
/// characters are shown or copied, so a malformed value can never dress up an alert.
struct BitcoinUnresolvedTransferModel: Equatable {
    let txid: String

    init?(txid: String) {
        guard txid.utf8.count == 64,
              txid.utf8.allSatisfy({ byte in
                  (48 ... 57).contains(byte) || (97 ... 102).contains(byte)
              })
        else {
            return nil
        }
        self.txid = txid
    }
}

struct SendLoadingCollector {
    var feeReady: Bool = false
    var balanceReady: Bool = false
    var utilityBalanceReady: Bool = false
    var edReady: Bool = false

    mutating func reset(isUtility: Bool) {
        feeReady = false
        balanceReady = false
        utilityBalanceReady = !isUtility
        edReady = false
    }

    var isReady: Bool {
        [
            feeReady,
            balanceReady,
            utilityBalanceReady,
            edReady
        ].allSatisfy { $0 }
    }
}

final class WalletSendConfirmPresenter {
    weak var view: WalletSendConfirmViewProtocol?
    private let wireframe: WalletSendConfirmWireframeProtocol
    private let interactor: WalletSendConfirmInteractorInputProtocol
    private let accountViewModelFactory: AccountViewModelFactoryProtocol
    private let dataValidatingFactory: SendDataValidatingFactory
    private let logger: LoggerProtocol?
    private let chainAsset: ChainAsset
    private let call: SendConfirmTransferCall
    private let wallet: MetaAccountModel
    private let walletSendConfirmViewModelFactory: WalletSendConfirmViewModelFactoryProtocol
    private let scamInfo: ScamInfo?
    private var feeViewModel: BalanceViewModelProtocol?

    private var balance: Decimal?
    private var utilityBalance: Decimal?
    private var fee: Decimal?
    private var minimumBalance: BigUInt?
    private var eqUilibriumTotalBalance: Decimal?
    private var pendingTonFeePresentation: BigUInt?
    private var confirmingTonFeePresentation: BigUInt?
    private var viewModelGeneration: UInt64 = 0
    private var isPresentingSendUnavailable = false
    private var isAwaitingBitcoinRequote = false
    private var bitcoinFeeRateSatPerVbyte: Double?
    /// The part of the Solana fee that opens the recipient's token account, shown on its own row.
    private var accountCreationDeposit: Decimal?
    private var solanaScreenActive = true
    private var solanaReviewActive: Bool {
        get {
            solanaScreenActive &&
                ((interactor as? WalletSendConfirmAttemptManaging)?.isSendSelectionCurrent ?? true)
        }

        set { solanaScreenActive = newValue }
    }

    private var solanaReceiptsAllowed = true
    private var solanaAttemptInProgress = false
    private var solanaSuccessDelivered = false
    private var solanaReviewGeneration = UUID()
    private var solanaRecoveryReceipt: UUID?

    private var loadingCollector = SendLoadingCollector()
    private var priceData: PriceData? {
        AssetTrustResolver.displayPrice(for: chainAsset, currency: wallet.selectedCurrency)
    }

    init(
        interactor: WalletSendConfirmInteractorInputProtocol,
        wireframe: WalletSendConfirmWireframeProtocol,
        accountViewModelFactory: AccountViewModelFactoryProtocol,
        dataValidatingFactory: SendDataValidatingFactory,
        walletSendConfirmViewModelFactory: WalletSendConfirmViewModelFactoryProtocol,
        logger: LoggerProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        call: SendConfirmTransferCall,
        scamInfo: ScamInfo?,
        feeViewModel: BalanceViewModelProtocol?,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.accountViewModelFactory = accountViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.walletSendConfirmViewModelFactory = walletSendConfirmViewModelFactory
        self.logger = logger
        self.chainAsset = chainAsset
        self.call = call
        self.wallet = wallet
        self.scamInfo = scamInfo
        self.feeViewModel = chainAsset.chain.isTonCompatibilityChain ? nil : feeViewModel
        self.localizationManager = localizationManager
        if let feeViewModel, !chainAsset.chain.isTonCompatibilityChain {
            fee = Decimal(string: feeViewModel.amount)
        }
        loadingCollector.feeReady = !chainAsset.chain.isTonCompatibilityChain && feeViewModel != nil
    }

    private func provideViewModel() {
        viewModelGeneration = viewModelGeneration == UInt64.max ? 1 : viewModelGeneration + 1
        let generation = viewModelGeneration
        Task { @MainActor [weak self] in
            guard let self else { return }
            let amount = Decimal.fromSubstrateAmount(call.amount, precision: Int16(chainAsset.asset.precision)) ?? .zero
            let parameters = WalletSendConfirmViewModelFactoryParameters(
                amount: amount,
                senderAccountViewModel: provideSenderAccountViewModel(),
                receiverAccountViewModel: provideReceiverAccountViewModel(),
                assetBalanceViewModel: try await provideAssetVewModel(),
                tipRequired: chainAsset.chain.isTipRequired,
                tipViewModel: try await provideTipViewModel(),
                feeViewModel: feeViewModel,
                wallet: wallet,
                locale: selectedLocale,
                scamInfo: scamInfo,
                assetModel: chainAsset.asset,
                chain: chainAsset.chain,
                accountCreationDepositViewModel: provideAccountCreationDepositViewModel()
            )
            let viewModel = walletSendConfirmViewModelFactory.buildViewModel(
                parameters: parameters
            )

            guard generation == viewModelGeneration else { return }
            view?.didReceive(state: .loaded(viewModel))
            confirmPendingTonFeePresentationIfNeeded()
        }
    }

    @MainActor
    private func confirmPendingTonFeePresentationIfNeeded() {
        guard chainAsset.chain.isTonCompatibilityChain,
              let rawFee = pendingTonFeePresentation,
              confirmingTonFeePresentation != rawFee
        else {
            return
        }
        confirmingTonFeePresentation = rawFee
        interactor.confirmFeePresentation(fee: rawFee) { [weak self] accepted in
            guard let self else { return }
            guard pendingTonFeePresentation == rawFee else {
                if confirmingTonFeePresentation == rawFee {
                    confirmingTonFeePresentation = nil
                }
                return
            }
            confirmingTonFeePresentation = nil
            guard accepted else {
                loadingCollector.feeReady = false
                checkLoadingState()
                return
            }
            pendingTonFeePresentation = nil
            loadingCollector.feeReady = true
            checkLoadingState()
        }
    }

    private func provideReceiverAccountViewModel() -> AccountViewModel? {
        let title = R.string.localizable
            .walletSendReceiverTitle(preferredLanguages: selectedLocale.rLanguages)

        return accountViewModelFactory.buildViewModel(
            title: title,
            address: call.receiverAddress,
            locale: selectedLocale
        )
    }

    private func provideSenderAccountViewModel() -> AccountViewModel? {
        guard let senderAddress = Self.senderAddress(
            for: chainAsset.chain,
            wallet: wallet
        ) else {
            return nil
        }

        let title = R.string.localizable
            .transactionDetailsFrom(preferredLanguages: selectedLocale.rLanguages)

        return accountViewModelFactory.buildViewModel(
            title: title,
            address: senderAddress,
            locale: selectedLocale
        )
    }

    static func senderAddress(
        for chain: ChainModel,
        wallet: MetaAccountModel
    ) -> String? {
        if let universalAddress = UniversalWalletAccountAddressResolver.address(
            for: chain,
            wallet: wallet
        ) {
            return universalAddress
        }

        guard let accountId = wallet.fetch(for: chain.accountRequest())?.accountId else {
            return nil
        }

        return try? AddressFactory.address(for: accountId, chain: chain)
    }

    private func provideAssetVewModel() async throws -> AssetBalanceViewModelProtocol? {
        let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: chainAsset)
        let amount = Decimal.fromSubstrateAmount(call.amount, precision: Int16(chainAsset.asset.precision)) ?? .zero
        return balanceViewModelFactory?.createAssetBalanceViewModel(
            amount,
            balance: balance,
            priceData: priceData
        ).value(for: selectedLocale)
    }

    private func provideTipViewModel() async throws -> BalanceViewModelProtocol? {
        guard
            let utilityAsset = interactor.getFeePaymentChainAsset(for: chainAsset),
            let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: utilityAsset)
        else { return nil }

        let tip = Decimal.fromSubstrateAmount(call.tip ?? .zero, precision: Int16(chainAsset.asset.precision))
        return tip
            .map { balanceViewModelFactory.balanceFromPrice($0, priceData: priceData, usageCase: .detailsCrypto) }?
            .value(for: selectedLocale)
    }

    private func updateFeeViewModel() {
        guard
            let utilityAsset = interactor.getFeePaymentChainAsset(for: chainAsset),
            let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: utilityAsset)
        else {
            return
        }
        let utilityPriceData = utilityAsset.asset.getPrice(for: wallet.selectedCurrency)
        let feeUsageCase: NumberFormatterUsageCase = chainAsset.chain.isTonCompatibilityChain
            ? .exactCrypto(fractionDigits: Int(utilityAsset.asset.precision))
            : .detailsCrypto

        let viewModel = fee
            .map {
                balanceViewModelFactory.balanceFromPrice(
                    $0,
                    priceData: utilityPriceData,
                    usageCase: feeUsageCase
                )
            }?
            .value(for: selectedLocale)
        feeViewModel = viewModel.map { withBitcoinFeeRate($0) }
    }

    private func provideAccountCreationDepositViewModel() -> BalanceViewModelProtocol? {
        guard
            let deposit = accountCreationDeposit,
            let utilityAsset = interactor.getFeePaymentChainAsset(for: chainAsset),
            let balanceViewModelFactory = buildBalanceViewModelFactory(wallet: wallet, for: utilityAsset)
        else {
            return nil
        }
        return balanceViewModelFactory.balanceFromPrice(
            deposit,
            priceData: utilityAsset.asset.getPrice(for: wallet.selectedCurrency),
            usageCase: .detailsCrypto
        ).value(for: selectedLocale)
    }

    /// "0.00000282 BTC · 2 sat/vB": a Bitcoin fee is shown with the rate of the exact quote,
    /// which is what decides how fast it confirms.
    private func withBitcoinFeeRate(_ viewModel: BalanceViewModelProtocol) -> BalanceViewModelProtocol {
        guard isBitcoinTransfer, let rate = bitcoinFeeRateSatPerVbyte else {
            return viewModel
        }
        return BalanceViewModel(
            amount: "\(viewModel.amount) · \(Self.formatFeeRate(rate, locale: selectedLocale))",
            price: viewModel.price
        )
    }

    static func formatFeeRate(_ satPerVbyte: Double, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = satPerVbyte < 10 ? 2 : 0
        let value = formatter.string(from: NSNumber(value: satPerVbyte)) ?? String(satPerVbyte)
        return "\(value) sat/vB"
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
            selectedMetaAccount: wallet
        )
        return balanceViewModelFactory
    }

    private func validateAndSubmitTransfer() {
        let amount = Decimal.fromSubstrateAmount(call.amount, precision: Int16(chainAsset.asset.precision)) ?? .zero
        let tipPaymentChainAsset = interactor.getFeePaymentChainAsset(for: chainAsset)
        let tipPaymentPrecision = tipPaymentChainAsset?.asset.precision ?? chainAsset.asset.precision
        let tip = Decimal.fromSubstrateAmount(call.tip ?? .zero, precision: Int16(tipPaymentPrecision)) ?? .zero

        let balanceType: BalanceType = !chainAsset.isUtility ?
            .orml(balance: balance, utilityBalance: utilityBalance) : .utility(balance: balance)

        let generation = solanaReviewGeneration
        DataValidationRunner(validators: [
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: balanceType,
                feeAndTip: (fee ?? 0) + tip,
                sendAmount: amount,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            guard let strongSelf = self else { return }
            if strongSelf.isSolanaTransfer {
                guard strongSelf.solanaReviewGeneration == generation,
                      strongSelf.beginSolanaAttempt() else { return }
            }
            let admittedGeneration = strongSelf.solanaReviewGeneration
            strongSelf.view?.didStartLoading()
            guard !strongSelf.isSolanaTransfer ||
                (strongSelf.solanaReviewActive &&
                    strongSelf.solanaReviewGeneration == admittedGeneration) else { return }
            strongSelf.interactor.submitExtrinsic()
        }
    }

    private func submitXorlessTransfer() {
        guard !isSolanaTransfer || beginSolanaAttempt() else { return }
        let generation = solanaReviewGeneration
        view?.didStartLoading()
        guard !isSolanaTransfer || (solanaReviewActive && solanaReviewGeneration == generation) else { return }
        interactor.submitExtrinsic()
    }

    private func checkLoadingState() {
        let update = { [weak self] in
            guard let self else { return }
            view?.didReceive(isLoading: !loadingCollector.isReady)
        }
        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }

    private func presentTonUnknownOutcome(messageHashHex: String) -> Bool {
        guard let recovery = TonUnknownOutcomeRecoveryModel(
            messageHashHex: messageHashHex
        ) else {
            return false
        }

        let copyAction = SheetAlertPresentableAction(
            title: tonRecoveryLocalizedString(
                key: "ton.transfer.unknown.copy_hash",
                fallback: "Copy message hash"
            ),
            style: .pinkBackgroundWhiteText
        ) {
            UIPasteboard.general.string = recovery.messageHashHex
        }
        let messageTemplate = tonRecoveryLocalizedString(
            key: "ton.transfer.unknown.message",
            fallback: "The network may have accepted this transfer. Do not send it again. " +
                "Save this message hash and check its status before taking further action:\n%@"
        )
        let viewModel = SheetAlertPresentableViewModel(
            title: tonRecoveryLocalizedString(
                key: "ton.transfer.unknown.title",
                fallback: "Transfer status is unknown"
            ),
            message: String(
                format: messageTemplate,
                locale: selectedLocale,
                recovery.messageHashHex
            ),
            actions: [copyAction],
            closeAction: R.string.localizable.commonClose(
                preferredLanguages: selectedLocale.rLanguages
            ),
            icon: R.image.iconWarningBig()
        )
        wireframe.present(viewModel: viewModel, from: view)
        return true
    }

    private func presentTonPriorTransferConfirmed(
        identity: TonTransferIntentIdentity,
        messageHashHex: String
    ) -> Bool {
        guard let recovery = TonUnknownOutcomeRecoveryModel(
            messageHashHex: messageHashHex
        ) else {
            return false
        }

        pendingTonFeePresentation = nil
        confirmingTonFeePresentation = nil
        loadingCollector.feeReady = false
        checkLoadingState()

        let acknowledgeAction = SheetAlertPresentableAction(
            title: tonRecoveryLocalizedString(
                key: "ton.transfer.prior_confirmed.acknowledge",
                fallback: "Acknowledge and recalculate fee"
            ),
            style: .pinkBackgroundWhiteText
        ) { [weak self] in
            guard let self else { return }
            interactor.acknowledgeSubmittedTransfer(
                hash: recovery.messageHashHex,
                recoveredIdentity: identity
            ) { [weak self] acknowledged in
                guard let self else { return }
                if acknowledged {
                    interactor.refreshFee()
                } else if let view {
                    wireframe.presentExtrinsicFailed(from: view, locale: selectedLocale)
                }
            }
        }
        let messageTemplate = tonRecoveryLocalizedString(
            key: "ton.transfer.prior_confirmed.message",
            fallback: "A previous transfer was confirmed. This new transfer was not sent. " +
                "Review and acknowledge the previous hash before confirming again:\n%@"
        )
        let viewModel = SheetAlertPresentableViewModel(
            title: tonRecoveryLocalizedString(
                key: "ton.transfer.prior_confirmed.title",
                fallback: "Previous transfer confirmed"
            ),
            message: String(
                format: messageTemplate,
                locale: selectedLocale,
                recovery.messageHashHex
            ),
            actions: [acknowledgeAction],
            closeAction: R.string.localizable.commonClose(
                preferredLanguages: selectedLocale.rLanguages
            ),
            icon: R.image.iconWarningBig()
        )
        wireframe.present(viewModel: viewModel, from: view)
        return true
    }

    private enum BitcoinRecoveryChoice {
        case close
        case retry
        case replace
    }

    private var isBitcoinTransfer: Bool {
        UniversalWalletRegistry.bitcoinNetwork(for: chainAsset.chain.chainId) != nil
    }

    private func bitcoinCopyAction(_ recovery: BitcoinUnresolvedTransferModel) -> SheetAlertPresentableAction {
        SheetAlertPresentableAction(
            title: recoveryLocalizedString(
                key: "bitcoin.transfer.copy_txid",
                fallback: "Copy transaction ID"
            )
        ) {
            UIPasteboard.general.string = recovery.txid
        }
    }

    /// The signed transaction may be with the network. Retrying sends those same bytes again,
    /// which can only ever be the one payment.
    private func presentBitcoinUnknownOutcome(txid: String) -> Bool {
        guard let recovery = BitcoinUnresolvedTransferModel(txid: txid) else {
            return false
        }

        var choice = BitcoinRecoveryChoice.close
        let retryAction = SheetAlertPresentableAction(
            title: recoveryLocalizedString(
                key: "bitcoin.transfer.unknown.retry",
                fallback: "Retry sending"
            ),
            style: .pinkBackgroundWhiteText
        ) {
            choice = .retry
        }
        let messageTemplate = recoveryLocalizedString(
            key: "bitcoin.transfer.unknown.message",
            fallback: "The Bitcoin network may have accepted this transfer. Don't send it again from " +
                "another wallet or app. Fearless kept the signed transaction: retrying sends that same " +
                "transaction, so it can't pay twice.\n%@"
        )
        let viewModel = SheetAlertPresentableViewModel(
            title: recoveryLocalizedString(
                key: "bitcoin.transfer.unknown.title",
                fallback: "Transfer status is unknown"
            ),
            message: String(format: messageTemplate, locale: selectedLocale, recovery.txid),
            actions: [retryAction, bitcoinCopyAction(recovery)],
            closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
            dismissCompletion: { [weak self] in
                if choice == .retry {
                    self?.retryUnresolvedBitcoinTransfer(recovery)
                }
            },
            icon: R.image.iconWarningBig()
        )
        wireframe.present(viewModel: viewModel, from: view)
        return true
    }

    /// An earlier transfer is still unresolved, so this one was not built. The user either
    /// retries the earlier one or replaces it; a replacement spends the same coins.
    private func presentBitcoinPriorTransferUnresolved(txid: String) -> Bool {
        guard let recovery = BitcoinUnresolvedTransferModel(txid: txid) else {
            return false
        }

        var choice = BitcoinRecoveryChoice.close
        let retryAction = SheetAlertPresentableAction(
            title: recoveryLocalizedString(
                key: "bitcoin.transfer.prior_unresolved.retry",
                fallback: "Retry the earlier transfer"
            ),
            style: .pinkBackgroundWhiteText
        ) {
            choice = .retry
        }
        let replaceAction = SheetAlertPresentableAction(
            title: recoveryLocalizedString(
                key: "bitcoin.transfer.prior_unresolved.replace",
                fallback: "Replace it with this transfer"
            )
        ) {
            choice = .replace
        }
        let messageTemplate = recoveryLocalizedString(
            key: "bitcoin.transfer.prior_unresolved.message",
            fallback: "Fearless couldn't confirm whether your earlier Bitcoin transfer was sent, so this " +
                "one was not sent. Retry the earlier transfer, or replace it with this one. A replacement " +
                "spends the same coins, so only one of the two can ever be confirmed.\n%@"
        )
        let viewModel = SheetAlertPresentableViewModel(
            title: recoveryLocalizedString(
                key: "bitcoin.transfer.prior_unresolved.title",
                fallback: "An earlier transfer is unresolved"
            ),
            message: String(format: messageTemplate, locale: selectedLocale, recovery.txid),
            actions: [retryAction, replaceAction, bitcoinCopyAction(recovery)],
            closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
            dismissCompletion: { [weak self] in
                switch choice {
                case .retry:
                    self?.retryUnresolvedBitcoinTransfer(recovery)
                case .replace:
                    self?.replaceUnresolvedBitcoinTransfer(recovery)
                case .close:
                    break
                }
            },
            icon: R.image.iconWarningBig()
        )
        wireframe.present(viewModel: viewModel, from: view)
        return true
    }

    /// The earlier transfer did reach the network. Nothing new was sent; the fee and balance
    /// are read again so a deliberate second transfer starts from the real coin set.
    private func presentBitcoinPriorTransferConfirmed(txid: String) -> Bool {
        guard let recovery = BitcoinUnresolvedTransferModel(txid: txid) else {
            return false
        }

        let messageTemplate = recoveryLocalizedString(
            key: "bitcoin.transfer.prior_sent.message",
            fallback: "Your earlier Bitcoin transfer reached the network, so this one was not sent. " +
                "Check the balance and fee before you send again.\n%@"
        )
        let viewModel = SheetAlertPresentableViewModel(
            title: recoveryLocalizedString(
                key: "bitcoin.transfer.prior_sent.title",
                fallback: "Your earlier transfer was sent"
            ),
            message: String(format: messageTemplate, locale: selectedLocale, recovery.txid),
            actions: [bitcoinCopyAction(recovery)],
            closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
            dismissCompletion: { [weak self] in
                self?.requoteBitcoinTransfer()
            },
            icon: R.image.iconWarningBig()
        )
        wireframe.present(viewModel: viewModel, from: view)
        return true
    }

    /// Nothing left the wallet and the reason is known; the user may simply try again.
    private func presentBitcoinTransferNotSent(_ reason: BitcoinTransferNotSentReason) {
        let message: String
        switch reason {
        case .noConnection:
            message = recoveryLocalizedString(
                key: "bitcoin.transfer.not_sent.no_connection",
                fallback: "Fearless couldn't reach the Bitcoin network, so nothing left your wallet. " +
                    "Check your connection and try again."
            )
        case .rejectedByNetwork:
            message = recoveryLocalizedString(
                key: "bitcoin.transfer.not_sent.rejected",
                fallback: "The Bitcoin network didn't accept this transfer, so nothing left your wallet. " +
                    "Review the amount and fee, then try again."
            )
        case .coinsAlreadySpent:
            message = recoveryLocalizedString(
                key: "bitcoin.transfer.not_sent.coins_spent",
                fallback: "The earlier transfer can no longer be confirmed, because another transaction " +
                    "spent its coins. Nothing more was sent. You can send again."
            )
        }
        let viewModel = SheetAlertPresentableViewModel(
            title: recoveryLocalizedString(
                key: "bitcoin.transfer.not_sent.title",
                fallback: "This transfer wasn't sent"
            ),
            message: message,
            actions: [],
            closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
            dismissCompletion: { [weak self] in
                self?.requoteBitcoinTransfer()
            },
            icon: R.image.iconWarningBig()
        )
        wireframe.present(viewModel: viewModel, from: view)
    }

    private var isSolanaTransfer: Bool {
        UniversalWalletRegistry.solanaNetwork(for: chainAsset.chain.chainId) != nil
    }

    private func solanaCopyAction(_ signature: String, localizedTitle: String? = nil) -> SheetAlertPresentableAction {
        let receipt = solanaRecoveryReceipt
        return SheetAlertPresentableAction(
            title: localizedTitle ?? recoveryLocalizedString(
                key: "solana.transfer.copy_signature",
                fallback: "Copy transaction ID"
            )
        ) { [weak self] in
            guard let self, self.solanaReviewActive, self.solanaRecoveryReceipt == receipt else { return }
            UIPasteboard.general.string = signature
        }
    }

    /// The cluster may have the transfer. Retrying sends the same signed bytes, which carry the
    /// same signature. Expiry requires independent finalized blockhash evidence; elapsed time
    /// or an unverified stored height cannot establish that the payment is safe to replace.
    private func presentSolanaUnknownOutcome(signature: String) -> Bool {
        guard let signature = try? SolanaRpcRoutes.normalizeSignature(signature) else {
            return false
        }

        let receipt = UUID()
        solanaRecoveryReceipt = receipt
        var retries = false
        let retryAction = SheetAlertPresentableAction(
            title: recoveryLocalizedString(
                key: "solana.transfer.unknown.retry",
                fallback: "Retry sending"
            ),
            style: .pinkBackgroundWhiteText
        ) { [weak self] in
            guard let self, self.solanaReviewActive, self.solanaRecoveryReceipt == receipt else { return }
            retries = true
        }
        let messageTemplate = recoveryLocalizedString(
            key: "solana.transfer.unknown.message",
            fallback: "The Solana network may have accepted this transfer. Don't send it again from another " +
                "wallet or app. Fearless kept the signed transaction: retrying sends that same transaction, so " +
                "it can't pay twice. A Solana transfer completes or expires within about two minutes.\n%@"
        )
        let viewModel = SheetAlertPresentableViewModel(
            title: recoveryLocalizedString(
                key: "solana.transfer.unknown.title",
                fallback: "Transfer status is unknown"
            ),
            message: String(format: messageTemplate, locale: selectedLocale, signature),
            actions: [retryAction, solanaCopyAction(signature)],
            closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
            dismissCompletion: { [weak self] in
                guard let self, self.consumeSolanaRecovery(receipt) else { return }
                if retries, self.beginSolanaAttempt() {
                    let generation = self.solanaReviewGeneration
                    self.view?.didStartLoading()
                    guard self.solanaReviewActive, self.solanaReviewGeneration == generation else { return }
                    self.interactor.retryUnresolvedTransfer(hash: signature)
                }
            },
            icon: R.image.iconWarningBig()
        )
        wireframe.present(viewModel: viewModel, from: view)
        return true
    }

    /// Nothing was signed for this transfer. Every case reads the fee and balance again on close.
    private func presentSolanaPriorTransfer(_ error: TransferServiceError) -> Bool {
        if case .solanaRecoveryRecordUnreadable = error {
            presentUnreadableSolanaRecord()
            return true
        }
        let titleKey: String
        let titleFallback: String
        let messageKey: String
        let messageFallback: String
        let signature: String
        var unavailableIdentity = false

        switch error {
        case let .solanaRecoveryUnavailable(value):
            unavailableIdentity = true
            signature = value
            titleKey = "solana.transfer.recovery_unavailable.title"
            titleFallback = "Saved transfer needs review"
            messageKey = "solana.transfer.recovery_unavailable.message"
            messageFallback = "The original network for this saved transfer cannot be verified. Fearless has kept " +
                "the transfer record. Status checks and retry are unavailable. Do not send a replacement " +
                "until the original transfer is resolved.\n%@"
        case let .solanaPriorTransferUnresolved(value):
            signature = value
            titleKey = "solana.transfer.prior_unresolved.title"
            titleFallback = "An earlier transfer is still in progress"
            messageKey = "solana.transfer.prior_unresolved.message"
            messageFallback = "Fearless is still checking whether your earlier Solana transfer was sent, so this " +
                "one was not sent. A Solana transfer completes or expires within about two minutes. Try again " +
                "then.\n%@"
        case let .solanaPriorTransferConfirmed(value):
            signature = value
            titleKey = "solana.transfer.prior_sent.title"
            titleFallback = "Your earlier transfer was sent"
            messageKey = "solana.transfer.prior_sent.message"
            messageFallback = "Your earlier Solana transfer reached the network, so this one was not sent. Check " +
                "the balance and fee before you send again.\n%@"
        case let .solanaPriorTransferNotSent(value):
            signature = value
            titleKey = "solana.transfer.prior_not_sent.title"
            titleFallback = "Your earlier transfer didn't go through"
            messageKey = "solana.transfer.prior_not_sent.message"
            messageFallback = "Your earlier Solana transfer was not confirmed by the network, so nothing left your " +
                "wallet for it. This transfer was not sent either. Review it and send again.\n%@"
        case let .solanaTransferUnverified(value):
            signature = value
            titleKey = "solana.transfer.unverified.title"
            titleFallback = "This transfer could not be verified"
            messageKey = "solana.transfer.unverified.message"
            messageFallback = "Fearless could not confirm whether this Solana transfer reached the network. Check " +
                "your balance and look up the transaction on Solscan before you send again.\n%@"
        case let .solanaPriorTransferUnverified(value):
            signature = value
            titleKey = "solana.transfer.prior_unverified.title"
            titleFallback = "Your earlier transfer could not be verified"
            messageKey = "solana.transfer.prior_unverified.message"
            messageFallback = "Fearless could not confirm whether your earlier Solana transfer reached the network, " +
                "so this transfer was not sent. Check your balance and look up the earlier transaction on Solscan. " +
                "If it did not go through, confirm this transfer again.\n%@"
        case let .solanaTransferFailed(value):
            signature = value
            titleKey = "solana.transfer.failed.title"
            titleFallback = "The transfer failed"
            messageKey = "solana.transfer.failed.message"
            messageFallback = "The Solana network processed this transfer but it failed, so the amount did not " +
                "leave your wallet. The network fee was charged.\n%@"
        default:
            return false
        }

        let receipt = UUID()
        solanaRecoveryReceipt = receipt
        let viewModel = SheetAlertPresentableViewModel(
            title: recoveryLocalizedString(key: titleKey, fallback: titleFallback),
            message: String(
                format: recoveryLocalizedString(key: messageKey, fallback: messageFallback),
                locale: selectedLocale,
                signature
            ),
            actions: [solanaCopyAction(
                signature,
                localizedTitle: unavailableIdentity
                    ? R.string.localizable.walletTransactionDetailCopyId(preferredLanguages: selectedLocale.rLanguages)
                    : nil
            )],
            closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
            dismissCompletion: { [weak self] in
                guard let self, self.consumeSolanaRecovery(receipt) else { return }
                self.requoteBitcoinTransfer()
            },
            icon: R.image.iconWarningBig(),
            scrollableContent: unavailableIdentity
        )
        wireframe.present(viewModel: viewModel, from: view)
        return true
    }

    private func presentUnreadableSolanaRecord() {
        let receipt = UUID()
        solanaRecoveryReceipt = receipt
        let viewModel = SheetAlertPresentableViewModel(
            title: recoveryLocalizedString(
                key: "solana.transfer.recovery_unavailable.title",
                fallback: "Saved transfer needs review"
            ),
            message: recoveryLocalizedString(
                key: "solana.transfer.recovery_unreadable.message",
                fallback: "Fearless cannot read a saved transfer record for this wallet and Solana network. " +
                    "The original data has been kept. Sending a new transfer, status checks and retry are " +
                    "unavailable because the earlier outcome is unknown. Do not send a replacement until " +
                    "the original transfer is resolved. Other wallet functions remain available."
            ),
            actions: [],
            closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
            dismissCompletion: { [weak self] in
                guard let self, self.consumeSolanaRecovery(receipt) else { return }
                self.requoteBitcoinTransfer()
            },
            icon: R.image.iconWarningBig(),
            scrollableContent: true
        )
        wireframe.present(viewModel: viewModel, from: view)
    }

    /// Nothing left the wallet and the reason is known; the user may simply try again.
    private func presentSolanaTransferNotSent(_ reason: SolanaTransferNotSentReason) {
        let message: String
        switch reason {
        case .noConnection:
            message = recoveryLocalizedString(
                key: "solana.transfer.not_sent.no_connection",
                fallback: "Fearless couldn't reach the Solana network, so nothing left your wallet. Check your " +
                    "connection and try again."
            )
        case .rejectedByNetwork:
            message = recoveryLocalizedString(
                key: "solana.transfer.not_sent.rejected",
                fallback: "The Solana network didn't accept this transfer, so nothing left your wallet. Review " +
                    "the amount and fee, then try again."
            )
        case .expired:
            message = recoveryLocalizedString(
                key: "solana.transfer.not_sent.expired",
                fallback: "This transfer expired before the Solana network confirmed it, so nothing left your " +
                    "wallet. You can send it again."
            )
        }
        let receipt = UUID()
        solanaRecoveryReceipt = receipt
        let viewModel = SheetAlertPresentableViewModel(
            title: recoveryLocalizedString(
                key: "solana.transfer.not_sent.title",
                fallback: "This transfer wasn't sent"
            ),
            message: message,
            actions: [],
            closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
            dismissCompletion: { [weak self] in
                guard let self, self.consumeSolanaRecovery(receipt) else { return }
                self.requoteBitcoinTransfer()
            },
            icon: R.image.iconWarningBig()
        )
        wireframe.present(viewModel: viewModel, from: view)
    }

    private func retryUnresolvedBitcoinTransfer(_ recovery: BitcoinUnresolvedTransferModel) {
        view?.didStartLoading()
        interactor.retryUnresolvedTransfer(hash: recovery.txid)
    }

    private func replaceUnresolvedBitcoinTransfer(_ recovery: BitcoinUnresolvedTransferModel) {
        view?.didStartLoading()
        interactor.allowReplacingUnresolvedTransfer(hash: recovery.txid) { [weak self] allowed in
            guard let self else { return }
            view?.didStopLoading()
            if allowed {
                // The replacement must spend the earlier transfer's coins, which changes its
                // fee: show that fee before the user confirms.
                requoteBitcoinTransfer()
            } else if let view {
                wireframe.presentExtrinsicFailed(from: view, locale: selectedLocale)
            }
        }
    }

    /// A Bitcoin fee quote is good for one attempt. After any attempt the fee and the
    /// spendable balance are read again, so the next Confirm is quoted on the current coins.
    /// Solana does the same after an attempt, because the balance it was quoted on changed.
    private func requoteBitcoinTransfer() {
        guard isBitcoinTransfer || isSolanaTransfer else {
            return
        }
        isAwaitingBitcoinRequote = true
        view?.didStartLoading()
        interactor.refreshFee()
    }

    private func finishBitcoinRequote() {
        guard isAwaitingBitcoinRequote else {
            return
        }
        isAwaitingBitcoinRequote = false
        view?.didStopLoading()
    }

    private func acceptSolanaOutcome(_ result: Swift.Result<String, Error>) -> Bool {
        guard isSolanaTransfer else { return true }
        guard solanaReviewActive, solanaReceiptsAllowed, !solanaSuccessDelivered else { return false }
        solanaAttemptInProgress = false
        solanaRecoveryReceipt = nil
        if case .success = result {
            solanaSuccessDelivered = true
        }
        if case let .failure(error) = result, error is CancellationError {
            view?.didStopLoading()
            return false
        }
        return true
    }

    private func completeTransferAfterVisibleReceipt(hash: String) {
        guard chainAsset.chain.isTonCompatibilityChain else {
            wireframe.complete(on: view, title: hash, chainAsset: chainAsset)
            return
        }
        guard let completionWireframe = wireframe as? WalletSendConfirmCompletionPresenting else {
            // A custom router without a presentation callback may show success, but it must
            // not delete the durable tombstone on an unobservable scheduling boundary.
            wireframe.complete(on: view, title: hash, chainAsset: chainAsset)
            return
        }
        completionWireframe.completeAfterPresentation(
            on: view,
            title: hash,
            chainAsset: chainAsset
        ) { [weak self] in
            self?.interactor.acknowledgeSubmittedTransfer(
                hash: hash,
                recoveredIdentity: nil
            ) { [weak self] acknowledged in
                if !acknowledged {
                    self?.logger?.error("TON confirmed receipt acknowledgement failed; tombstone retained")
                }
            }
        }
    }

    /// A remote veto can land after Send routed the network. Nothing was signed or sent;
    /// the user leaves the flow or goes to Receive for the same network.
    private func presentSendUnavailable(_ reason: SendUnavailableReason) {
        guard !isPresentingSendUnavailable else {
            return
        }
        isPresentingSendUnavailable = true

        let languages = selectedLocale.rLanguages
        var showsReceive = false
        let receiveAction = SheetAlertPresentableAction(
            title: R.string.localizable.commonActionReceive(preferredLanguages: languages),
            style: .pinkBackgroundWhiteText
        ) {
            showsReceive = true
        }
        let viewModel = SheetAlertPresentableViewModel(
            title: reason.title(for: selectedLocale),
            message: reason.message(for: selectedLocale),
            actions: reason.offersReceive ? [receiveAction] : [],
            closeAction: R.string.localizable.commonClose(preferredLanguages: languages),
            dismissCompletion: { [weak self] in
                guard let self else { return }
                if showsReceive {
                    wireframe.presentReceive(leavingSendFlowFrom: view, chainAsset: chainAsset, wallet: wallet)
                } else {
                    wireframe.finish(view: view)
                }
            },
            icon: R.image.iconWarningBig()
        )
        wireframe.present(viewModel: viewModel, from: view)
    }

    /// The same lookup for the Bitcoin recovery copy; nothing in it is specific to TON.
    private func recoveryLocalizedString(key: String, fallback: String) -> String {
        tonRecoveryLocalizedString(key: key, fallback: fallback)
    }

    private func tonRecoveryLocalizedString(key: String, fallback: String) -> String {
        Bundle.localizationBundle(for: selectedLocale).localizedString(
            forKey: key,
            value: fallback,
            table: "Localizable"
        )
    }
}

extension WalletSendConfirmPresenter: WalletSendConfirmPresenterProtocol {
    func didTapScamWarningButton() {
        let title = R.string.localizable.scamWarningAlertTitle(
            chainAsset.asset.symbol.uppercased(),
            preferredLanguages: selectedLocale.rLanguages
        )
        let message = R.string.localizable.scamWarningAlertSubtitle(
            chainAsset.asset.symbolUppercased,
            preferredLanguages: selectedLocale.rLanguages
        )

        let sheetViewModel = SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: R.string.localizable.commonClose(preferredLanguages: selectedLocale.rLanguages),
            icon: R.image.iconWarningBig()
        )
        wireframe.present(
            viewModel: sheetViewModel,
            from: view
        )
    }

    func setup() {
        if chainAsset.chain.isTonCompatibilityChain {
            view?.didReceive(isLoading: true)
        }
        interactor.setup()
        provideViewModel()
        loadingCollector.utilityBalanceReady = chainAsset.isUtility
    }

    func didTapBackButton() {
        if isSolanaTransfer {
            guard solanaReviewActive else { return }
            suspendSendReview()
        }
        wireframe.close(view: view)
    }

    func didTapConfirmButton() {
        guard !isSolanaTransfer ||
            (solanaReviewActive && !solanaAttemptInProgress && !solanaSuccessDelivered),
            !chainAsset.chain.isTonCompatibilityChain || loadingCollector.isReady else {
            return
        }
        switch call {
        case .transfer:
            validateAndSubmitTransfer()
        case .xorlessTransfer:
            submitXorlessTransfer()
        }
    }
}

extension WalletSendConfirmPresenter: WalletSendConfirmInteractorOutputProtocol {
    func didReceiveFeeRate(satPerVbyte: Double) {
        bitcoinFeeRateSatPerVbyte = satPerVbyte
    }

    func didReceiveAccountCreationDeposit(_ deposit: BigUInt) {
        guard isSolanaTransfer, deposit > .zero,
              let utilityAsset = interactor.getFeePaymentChainAsset(for: chainAsset) else {
            accountCreationDeposit = nil
            return
        }
        accountCreationDeposit = Decimal.fromSubstrateAmount(deposit, precision: Int16(utilityAsset.asset.precision))
    }

    func didTransfer(result: Result<String, Error>) {
        let generation = solanaReviewGeneration
        guard acceptSolanaOutcome(result) else { return }
        view?.didStopLoading()
        guard !isSolanaTransfer || (solanaReviewActive && solanaReviewGeneration == generation) else { return }

        switch result {
        case let .success(hash):
            completeTransferAfterVisibleReceipt(hash: hash)
        case let .failure(error):
            guard let view = view else {
                return
            }

            if case let TransferServiceError.tonPriorTransferConfirmed(identity, messageHashHex) = error,
               presentTonPriorTransferConfirmed(
                   identity: identity,
                   messageHashHex: messageHashHex
               ) {
                return
            }

            if case let TransferServiceError.tonBroadcastOutcomeUnknown(messageHashHex) = error,
               presentTonUnknownOutcome(messageHashHex: messageHashHex) {
                return
            }

            if case let TransferServiceError.bitcoinBroadcastOutcomeUnknown(txid) = error,
               presentBitcoinUnknownOutcome(txid: txid) {
                return
            }

            if case let TransferServiceError.bitcoinPriorTransferUnresolved(txid) = error,
               presentBitcoinPriorTransferUnresolved(txid: txid) {
                return
            }

            if case let TransferServiceError.bitcoinPriorTransferConfirmed(txid) = error,
               presentBitcoinPriorTransferConfirmed(txid: txid) {
                return
            }

            if case let TransferServiceError.bitcoinTransferNotSent(reason) = error {
                presentBitcoinTransferNotSent(reason)
                return
            }

            if case let TransferServiceError.solanaBroadcastOutcomeUnknown(signature) = error,
               presentSolanaUnknownOutcome(signature: signature) {
                return
            }

            if let transferError = error as? TransferServiceError, presentSolanaPriorTransfer(transferError) {
                return
            }

            if case let TransferServiceError.solanaTransferNotSent(reason) = error {
                presentSolanaTransferNotSent(reason)
                return
            }

            if let reason = SendUnavailableReason(transferError: error) {
                presentSendUnavailable(reason)
                return
            }

            if let rpcError = error as? RPCResponse<EthereumData>.Error, rpcError.code == -32000 {
                wireframe.presentAmountTooHigh(from: view, locale: selectedLocale)
                return
            }

            if !wireframe.present(error: error, from: view, locale: selectedLocale) {
                wireframe.presentExtrinsicFailed(from: view, locale: selectedLocale)
            }
            if isBitcoinTransfer || isSolanaTransfer {
                // The failed attempt used up its fee quote; fetch a new one in the background so
                // Confirm works again once the user has read the error.
                interactor.refreshFee()
            }
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        switch result {
        case let .success(accountInfo):
            if chainAsset == self.chainAsset {
                loadingCollector.balanceReady = true
                checkLoadingState()

                balance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(chainAsset.asset.precision)
                    )
                } ?? 0.0

                provideViewModel()
            } else if let utilityAsset = interactor.getFeePaymentChainAsset(for: chainAsset),
                      utilityAsset == chainAsset {
                loadingCollector.utilityBalanceReady = true
                checkLoadingState()

                utilityBalance = accountInfo.map {
                    Decimal.fromSubstrateAmount(
                        $0.data.sendAvailable,
                        precision: Int16(utilityAsset.asset.precision)
                    )
                } ?? 0
            }
        case let .failure(error):
            logger?.error("Did receive account info error: \(error.logSafeDescription)")
        }
    }

    func didReceiveMinimumBalance(result: Result<BigUInt, Error>) {
        switch result {
        case let .success(minimumBalance):
            loadingCollector.edReady = true
            checkLoadingState()
            self.minimumBalance = minimumBalance

            provideViewModel()
        case let .failure(error):
            loadingCollector.edReady = true
            checkLoadingState()
            logger?.error("Did receive minimum balance error: \(error.logSafeDescription)")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(dispatchInfo):
            guard let utilityAsset = interactor.getFeePaymentChainAsset(for: chainAsset) else { return }
            let rawFee = BigUInt(string: dispatchInfo.fee)
            fee = rawFee.map {
                Decimal.fromSubstrateAmount($0, precision: Int16(utilityAsset.asset.precision))
            } ?? nil
            updateFeeViewModel()
            if chainAsset.chain.isTonCompatibilityChain {
                pendingTonFeePresentation = rawFee
                confirmingTonFeePresentation = nil
                loadingCollector.feeReady = false
                view?.didReceive(isLoading: true)
            }
            provideViewModel()
            let amount = Decimal.fromSubstrateAmount(call.amount, precision: Int16(chainAsset.asset.precision)) ?? .zero
            let tipPaymentChainAsset = interactor.getFeePaymentChainAsset(for: chainAsset)
            let tipPaymentPrecision = tipPaymentChainAsset?.asset.precision ?? chainAsset.asset.precision
            let tip = Decimal.fromSubstrateAmount(call.tip ?? .zero, precision: Int16(tipPaymentPrecision)) ?? .zero

            let fullAmount = amount + fee.or(.zero) + tip
            interactor.fetchEquilibriumTotalBalance(chainAsset: chainAsset, amount: fullAmount)
            if !chainAsset.chain.isTonCompatibilityChain {
                loadingCollector.feeReady = true
                checkLoadingState()
            }
            finishBitcoinRequote()
        case let .failure(error):
            finishBitcoinRequote()
            if chainAsset.chain.isTonCompatibilityChain {
                pendingTonFeePresentation = nil
                confirmingTonFeePresentation = nil
                loadingCollector.feeReady = false
                view?.didReceive(isLoading: true)
            }
            logger?.error("Did receive fee error: \(error.logSafeDescription)")
            if let reason = SendUnavailableReason(transferError: error) {
                presentSendUnavailable(reason)
            }
        }
    }

    func didReceive(eqTotalBalance: Decimal) {
        eqUilibriumTotalBalance = eqTotalBalance
        loadingCollector.balanceReady = true
        checkLoadingState()
    }
}

extension WalletSendConfirmPresenter: Localizable {
    func applyLocalization() {}
}

extension WalletSendConfirmPresenter: WalletSendConfirmScopeManaging {
    var hasOwnedRecoveryPresentation: Bool {
        isSolanaTransfer && solanaReviewActive && solanaRecoveryReceipt != nil
    }

    func resumeSendReview() {
        guard isSolanaTransfer else { return }
        solanaReviewActive = true
        // Returning permits a fresh explicit Confirm, never delivery of the departed attempt.
    }

    func suspendSendReview() {
        guard isSolanaTransfer else { return }
        solanaReviewActive = false
        solanaReceiptsAllowed = false
        solanaReviewGeneration = UUID()
        solanaRecoveryReceipt = nil
        solanaAttemptInProgress = false
        (interactor as? WalletSendConfirmAttemptManaging)?.cancelSendAttempt()
        view?.didStopLoading()
    }

    private func beginSolanaAttempt() -> Bool {
        guard solanaReviewActive, !solanaAttemptInProgress, !solanaSuccessDelivered else { return false }
        // Synchronous UI callbacks may start another attempt while an earlier outcome is delivered.
        solanaReviewGeneration = UUID()
        solanaAttemptInProgress = true
        solanaReceiptsAllowed = true
        solanaRecoveryReceipt = nil
        return true
    }

    private func consumeSolanaRecovery(_ receipt: UUID) -> Bool {
        guard solanaReviewActive, solanaRecoveryReceipt == receipt else { return false }
        solanaRecoveryReceipt = nil
        return true
    }
}
