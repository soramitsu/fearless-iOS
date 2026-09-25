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

    private var loadingCollector = SendLoadingCollector()
    private var priceData: PriceData? {
        chainAsset.asset.getPrice(for: wallet.selectedCurrency)
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
                assetModel: chainAsset.asset
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
        feeViewModel = viewModel
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

        DataValidationRunner(validators: [
            dataValidatingFactory.canPayFeeAndAmount(
                balanceType: balanceType,
                feeAndTip: (fee ?? 0) + tip,
                sendAmount: amount,
                locale: selectedLocale
            )
        ]).runValidation { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.view?.didStartLoading()
            strongSelf.interactor.submitExtrinsic()
        }
    }

    private func submitXorlessTransfer() {
        view?.didStartLoading()
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

    private func tonRecoveryLocalizedString(key: String, fallback: String) -> String {
        for language in selectedLocale.rLanguages ?? [] {
            if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle.localizedString(
                    forKey: key,
                    value: fallback,
                    table: "Localizable"
                )
            }
        }
        return Bundle.main.localizedString(
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
        wireframe.close(view: view)
    }

    func didTapConfirmButton() {
        guard !chainAsset.chain.isTonCompatibilityChain || loadingCollector.isReady else {
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
    func didTransfer(result: Result<String, Error>) {
        view?.didStopLoading()

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

            if let rpcError = error as? RPCResponse<EthereumData>.Error, rpcError.code == -32000 {
                wireframe.presentAmountTooHigh(from: view, locale: selectedLocale)
                return
            }

            if !wireframe.present(error: error, from: view, locale: selectedLocale) {
                wireframe.presentExtrinsicFailed(from: view, locale: selectedLocale)
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
            logger?.error("Did receive account info error: \(error)")
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
            logger?.error("Did receive minimum balance error: \(error)")
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
        case let .failure(error):
            if chainAsset.chain.isTonCompatibilityChain {
                pendingTonFeePresentation = nil
                confirmingTonFeePresentation = nil
                loadingCollector.feeReady = false
                view?.didReceive(isLoading: true)
            }
            logger?.error("Did receive fee error: \(error)")
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
