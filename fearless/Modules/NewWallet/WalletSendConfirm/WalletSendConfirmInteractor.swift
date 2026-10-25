import UIKit
import RobinHood
import Web3
import IrohaCrypto
import SSFModels
import SSFCrypto
import SoraKeystore
import Web3PromiseKit

final class WalletSendConfirmInteractor: RuntimeConstantFetching {
    weak var presenter: WalletSendConfirmInteractorOutputProtocol?

    private let selectedMetaAccount: MetaAccountModel
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let call: SendConfirmTransferCall
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private var equilibriumTotalBalanceService: EquilibriumTotalBalanceServiceProtocol?
    private var tonFeePresentation: (fee: BigUInt, id: String)?
    private let accountInfoRemoteService: AccountInfoRemoteService
    let dependencyContainer: SendDepencyContainer
    private var balanceProvider: AnyDataProvider<DecodedAccountInfo>?
    private let prepareTransferService: (ChainAsset) async throws -> TransferServiceProtocol
    private var unscopedTransferTask: Task<Void, Never>?
    private let solanaAttempt: SolanaSendAttempt

    var transferTask: Task<Void, Never>? {
        ownsSolanaTransfer ? solanaAttempt.task : unscopedTransferTask
    }

    private var ownsSolanaTransfer: Bool {
        UniversalWalletRegistry.solanaNetwork(for: chainAsset.chain.chainId) != nil
    }

    private func startSolanaTransfer(retryHash: String? = nil) {
        solanaAttempt.start(retryHash: retryHash) { [weak self] result in
            self?.presenter?.didTransfer(result: result)
        }
    }

    init(
        selectedMetaAccount: MetaAccountModel,
        chainAsset: ChainAsset,
        call: SendConfirmTransferCall,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        dependencyContainer: SendDepencyContainer,
        wallet: MetaAccountModel,
        accountInfoRemoteService: AccountInfoRemoteService,
        prepareTransferService: ((ChainAsset) async throws -> TransferServiceProtocol)? = nil,
        selectedWalletSettings: SelectedWalletSettings = .shared,
        selection: SelectedWalletAuthority.Lease? = nil
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chainAsset = chainAsset
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.call = call
        self.dependencyContainer = dependencyContainer
        self.wallet = wallet
        self.accountInfoRemoteService = accountInfoRemoteService
        let prepare = prepareTransferService ?? { chainAsset in
            try await dependencyContainer.prepareDepencies(chainAsset: chainAsset).transferService
        }
        self.prepareTransferService = prepare
        solanaAttempt = SolanaSendAttempt(
            asset: chainAsset, call: call,
            selection: selection ?? selectedWalletSettings.sendAuthority.capture(for: wallet), prepare: prepare
        )
    }

    private func subscribeToAccountInfo() {
        if UniversalWalletRegistry.readsBalanceRemotely(chainAsset.chain.chainId) {
            // A Solana token transfer pays its fee in SOL, so that balance is read as well.
            var chainAssets = [chainAsset]
            if !chainAsset.isUtility,
               let utilityAsset = getFeePaymentChainAsset(for: chainAsset) {
                chainAssets.append(utilityAsset)
            }
            chainAssets.forEach(fetchRemoteAccountInfo)
            return
        }

        var chainsAssets = [chainAsset]
        if !chainAsset.isUtility,
           let utilityAsset = getFeePaymentChainAsset(for: chainAsset) {
            chainsAssets.append(utilityAsset)
        }
        accountInfoSubscriptionAdapter.subscribe(
            chainsAssets: chainsAssets,
            handler: self,
            deliveryOn: .main
        )
    }

    private func subscribeToFee() {
        switch call {
        case let .transfer(transfer):
            Task {
                do {
                    // The service that quotes the fee is the one that sends.
                    let transferService = try await prepareTransferService(chainAsset)
                    transferService.subscribeForFee(transfer: transfer, listener: self)
                } catch {
                    await MainActor.run {
                        presenter?.didReceiveFee(result: .failure(error))
                    }
                }
            }
        case .xorlessTransfer:
            break
        }
    }
}

extension WalletSendConfirmInteractor: WalletSendConfirmInteractorInputProtocol {
    func setup() {
        subscribeToAccountInfo()
        provideConstants()
        subscribeToFee()
    }

    func submitExtrinsic() {
        if ownsSolanaTransfer {
            startSolanaTransfer()
            return
        }
        unscopedTransferTask = Task {
            do {
                let transferService = try await prepareTransferService(chainAsset)

                let txHash: String
                switch call {
                case let .transfer(transfer):
                    txHash = try await transferService.submit(transfer: transfer)
                case let .xorlessTransfer(transfer):
                    txHash = try await transferService.submit(transfer: transfer)
                }

                await MainActor.run {
                    presenter?.didTransfer(result: .success(txHash))
                }
            } catch {
                await MainActor.run {
                    presenter?.didTransfer(result: .failure(error))
                }
            }
        }
    }

    func getFeePaymentChainAsset(for chainAsset: ChainAsset?) -> ChainAsset? {
        Self.resolveFeePaymentChainAsset(for: chainAsset)
    }

    static func resolveFeePaymentChainAsset(for chainAsset: ChainAsset?) -> ChainAsset? {
        guard let chainAsset else { return nil }
        // TON fee quotes are denominated in the selected native TON asset. Never select an
        // arbitrary member of the registry's utility-asset Set: a hostile or future extra
        // utility entry could otherwise change the visible precision/symbol while the raw
        // nanotons quote is acknowledged.
        if chainAsset.chain.isTonCompatibilityChain {
            return chainAsset
        }
        if let utilityAsset = chainAsset.chain.utilityAssets().first {
            return ChainAsset(chain: chainAsset.chain, asset: utilityAsset)
        }
        return chainAsset
    }

    func fetchEquilibriumTotalBalance(chainAsset: ChainAsset, amount: Decimal) {
        if chainAsset.chain.isEquilibrium {
            Task {
                let service = try await dependencyContainer
                    .prepareDepencies(chainAsset: chainAsset)
                    .equilibruimTotalBalanceService
                equilibriumTotalBalanceService = service

                let totalBalanceAfterTransfer = equilibriumTotalBalanceService?
                    .totalBalanceAfterTransfer(chainAsset: chainAsset, amount: amount) ?? .zero
                presenter?.didReceive(eqTotalBalance: totalBalanceAfterTransfer)
            }
        }
    }

    private func fetchRemoteAccountInfo(for chainAsset: ChainAsset) {
        Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let accountInfo = try await self.accountInfoRemoteService.fetchAccountInfo(
                    for: chainAsset,
                    wallet: self.wallet
                )
                await MainActor.run {
                    self.presenter?.didReceiveAccountInfo(
                        result: .success(accountInfo),
                        for: chainAsset
                    )
                }
            } catch {
                await MainActor.run {
                    self.presenter?.didReceiveAccountInfo(
                        result: .failure(error),
                        for: chainAsset
                    )
                }
            }
        }
    }

    func provideConstants() {
        if UniversalWalletRegistry.readsBalanceRemotely(chainAsset.chain.chainId) {
            presenter?.didReceiveMinimumBalance(result: .success(.zero))
            return
        }

        Task {
            let dependencies = try await dependencyContainer.prepareDepencies(chainAsset: chainAsset)

            dependencies.existentialDepositService.fetchExistentialDeposit(
                chainAsset: chainAsset
            ) { [weak self] result in
                self?.presenter?.didReceiveMinimumBalance(result: result)
            }
        }
    }

    func confirmFeePresentation(fee: BigUInt, completion: @escaping (Bool) -> Void) {
        guard chainAsset.chain.isTonCompatibilityChain else {
            completion(true)
            return
        }
        guard let presentation = tonFeePresentation,
              presentation.fee == fee
        else {
            completion(false)
            return
        }
        Task {
            let accepted: Bool
            do {
                let service = try await prepareTransferService(chainAsset)
                accepted = await service.confirmFeePresentation(
                    id: presentation.id,
                    fee: presentation.fee
                )
            } catch {
                accepted = false
            }
            await MainActor.run {
                completion(accepted)
            }
        }
    }

    func acknowledgeSubmittedTransfer(
        hash: String,
        recoveredIdentity: TonTransferIntentIdentity?,
        completion: @escaping (Bool) -> Void
    ) {
        guard case let .transfer(transfer) = call else {
            completion(false)
            return
        }
        Task {
            guard let service = try? await prepareTransferService(chainAsset) else {
                await MainActor.run { completion(false) }
                return
            }
            let acknowledged: Bool
            if let recoveredIdentity {
                acknowledged = await service.acknowledgeRecoveredTransfer(
                    hash: hash,
                    identity: recoveredIdentity
                )
            } else {
                acknowledged = await service.acknowledgeSubmittedTransfer(
                    hash: hash,
                    transfer: transfer
                )
            }
            await MainActor.run { completion(acknowledged) }
        }
    }

    func refreshFee() {
        tonFeePresentation = nil
        if UniversalWalletRegistry.readsBalanceRemotely(chainAsset.chain.chainId) {
            // A Bitcoin or Solana balance is fetched once, not subscribed to; after a transfer
            // attempt the spendable balance may have changed along with the fee.
            subscribeToAccountInfo()
        }
        subscribeToFee()
    }

    func retryUnresolvedTransfer(hash: String) {
        if ownsSolanaTransfer {
            startSolanaTransfer(retryHash: hash)
            return
        }
        unscopedTransferTask = Task {
            do {
                let transferService = try await prepareTransferService(chainAsset)
                let txHash = try await transferService.retryUnresolvedTransfer(hash: hash)

                await MainActor.run {
                    presenter?.didTransfer(result: .success(txHash))
                }
            } catch {
                await MainActor.run {
                    presenter?.didTransfer(result: .failure(error))
                }
            }
        }
    }

    func allowReplacingUnresolvedTransfer(hash: String, completion: @escaping (Bool) -> Void) {
        Task {
            let allowed: Bool
            if let service = try? await prepareTransferService(chainAsset) {
                allowed = await service.allowReplacingUnresolvedTransfer(hash: hash)
            } else {
                allowed = false
            }
            await MainActor.run { completion(allowed) }
        }
    }
}

extension WalletSendConfirmInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Swift.Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset: ChainAsset
    ) {
        presenter?.didReceiveAccountInfo(result: result, for: chainAsset)
    }
}

extension WalletSendConfirmInteractor: TransferFeeEstimationListener {
    func didReceiveFee(fee: BigUInt) {
        tonFeePresentation = nil
        DispatchQueue.main.async { [weak self] in
            self?.presenter?.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: fee)))
        }
    }

    func didReceiveFeeError(feeError: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.presenter?.didReceiveFee(result: .failure(feeError))
        }
    }
}

extension WalletSendConfirmInteractor: BitcoinTransferFeeRateListener {
    func didReceiveBitcoinFee(fee: BigUInt, feeRateSatPerVbyte: Double) {
        tonFeePresentation = nil
        DispatchQueue.main.async { [weak self] in
            self?.presenter?.didReceiveFeeRate(satPerVbyte: feeRateSatPerVbyte)
            self?.presenter?.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: fee)))
        }
    }
}

extension WalletSendConfirmInteractor: SolanaTransferFeeBreakdownListener {
    func didReceiveSolanaFee(fee: BigUInt, accountCreationDeposit: BigUInt) {
        tonFeePresentation = nil
        DispatchQueue.main.async { [weak self] in
            self?.presenter?.didReceiveAccountCreationDeposit(accountCreationDeposit)
            self?.presenter?.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: fee)))
        }
    }
}

extension WalletSendConfirmInteractor: TonTransferFeePresentationListener {
    func didReceiveTonFee(fee: BigUInt, presentationID: String) {
        DispatchQueue.main.async { [weak self] in
            // Preserve the exact opaque quote ID until the presenter confirms that this fee
            // has actually been applied to the view.
            self?.tonFeePresentation = (fee, presentationID)
            self?.presenter?.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: fee)))
        }
    }
}

extension WalletSendConfirmInteractor: WalletSendConfirmAttemptManaging {
    var isSendSelectionCurrent: Bool { !ownsSolanaTransfer || solanaAttempt.isSelectionCurrent }

    func cancelSendAttempt() {
        guard ownsSolanaTransfer else { return }
        solanaAttempt.cancel()
    }
}
