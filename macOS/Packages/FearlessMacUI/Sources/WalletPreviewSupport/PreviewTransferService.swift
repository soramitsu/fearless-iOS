import Foundation
import WalletCore

struct PreviewTransferService: TransferServicing {
    let store: PreviewStore

    func validateRecipient(_ address: String, on chainID: ChainID) async -> RecipientValidation {
        await store.pause(scale: 0.3)
        guard let chain = PreviewCatalog.chain(chainID) else { return .invalid(reason: "This network is not supported yet.") }
        return PreviewAddressCodec.validate(address, on: chain)
    }

    /// The asset fees are paid in and a sample fee for a transfer of `asset`.
    static func fee(for asset: Asset) -> FeeEstimate {
        let c = PreviewCatalog.self
        switch asset.chainID {
        case c.polkadot.id: return FeeEstimate(assetID: c.dot.id, amount: c.amount("0.0157", 10))
        case c.polkadotAssetHub.id: return FeeEstimate(assetID: c.dotAssetHub.id, amount: c.amount("0.0021", 10))
        case c.kusama.id: return FeeEstimate(assetID: c.ksm.id, amount: c.amount("0.000533", 12))
        case c.kusamaAssetHub.id: return FeeEstimate(assetID: c.ksmAssetHub.id, amount: c.amount("0.000071", 12))
        case c.westend.id: return FeeEstimate(assetID: c.wnd.id, amount: c.amount("0.0164", 12))
        case c.ethereum.id: return FeeEstimate(assetID: c.eth.id, amount: c.amount(asset.id.isNative ? "0.00042" : "0.0011", 18))
        case c.bnbSmartChain.id: return FeeEstimate(assetID: c.bnb.id, amount: c.amount("0.00021", 18))
        case c.polygon.id: return FeeEstimate(assetID: c.pol.id, amount: c.amount("0.0042", 18))
        default: return FeeEstimate(assetID: c.sepoliaETH.id, amount: c.amount("0.00003", 18))
        }
    }

    func prepare(_ request: TransferRequest) async -> TransferPreparation {
        await store.pause()
        guard let asset = PreviewCatalog.asset(request.assetID), let chain = PreviewCatalog.chain(request.assetID.chainID) else {
            return TransferPreparation(request: request, fee: nil, issues: [.unsupportedAsset], maxSendable: nil)
        }
        guard let wallet = try? await store.stored(request.walletID) else {
            return TransferPreparation(request: request, fee: nil, issues: [.network("This wallet no longer exists.")], maxSendable: nil)
        }
        if store.scenario.failingChains.contains(chain.id) {
            return TransferPreparation(
                request: request, fee: nil,
                issues: [.network("\(chain.name) did not answer, so the fee could not be estimated.")],
                maxSendable: nil
            )
        }

        var issues: [TransferIssue] = []
        if wallet.wallet.isWatchOnly { issues.append(.watchOnlyWallet) }

        let fee = Self.fee(for: asset)
        let zero = TokenAmount.zero(decimals: asset.decimals)
        let held = await store.held(request.walletID, request.assetID)
        let transferable = held?.transferable ?? zero
        let feeBalance = await store.held(request.walletID, fee.assetID)?.transferable ?? .zero(decimals: fee.amount.decimals)
        let paysFeeInSameAsset = fee.assetID == request.assetID
        let deposit = chain.ecosystem == .substrate ? (asset.existentialDeposit ?? zero) : zero

        var maxSendable = transferable
        if paysFeeInSameAsset { maxSendable = maxSendable.subtractingClamped(fee.amount) }
        if request.keepAlive, chain.ecosystem == .substrate { maxSendable = maxSendable.subtractingClamped(deposit) }

        switch PreviewAddressCodec.validate(request.recipient, on: chain) {
        case .valid(let normalized):
            if normalized == wallet.address(on: chain) { issues.append(.recipientIsSender) }
        case .empty:
            issues.append(.invalidRecipient("Enter the recipient's address."))
        case .invalid(let reason), .wrongNetwork(let reason):
            issues.append(.invalidRecipient(reason))
        }

        if request.amount.isZero {
            issues.append(.amountIsZero)
        } else if request.amount > transferable {
            issues.append(.insufficientBalance(available: transferable))
        } else {
            let needed = paysFeeInSameAsset ? (request.amount.adding(fee.amount) ?? request.amount) : fee.amount
            let available = paysFeeInSameAsset ? transferable : feeBalance
            if needed > available {
                issues.append(.insufficientBalanceForFee(fee: fee.amount))
            } else if chain.ecosystem == .substrate, !deposit.isZero {
                if request.amount < deposit, !Self.knownAccounts.contains(request.recipient) {
                    issues.append(.belowExistentialDeposit(minimum: deposit))
                }
                let spent = paysFeeInSameAsset ? (request.amount.adding(fee.amount) ?? request.amount) : request.amount
                let remaining = transferable.subtractingClamped(spent)
                if request.keepAlive, remaining < deposit {
                    issues.append(.wouldReapSender(minimumRemaining: deposit))
                }
            }
        }
        return TransferPreparation(request: request, fee: fee, issues: issues, maxSendable: maxSendable)
    }

    /// Accounts the preview treats as already existing on chain.
    private static let knownAccounts: Set<String> = {
        let accounts = [PreviewSampleData.alice, PreviewSampleData.bob, PreviewSampleData.charlie]
        return Set(accounts.flatMap { [$0.polkadot, $0.kusama, $0.generic] })
    }()

    func submit(_ request: TransferRequest, approval: UserApproval) async throws -> AsyncThrowingStream<TransferProgress, Error> {
        await store.pause()
        try await store.requireUnlocked()
        try await store.check(approval)
        let preparation = await prepare(request)
        guard preparation.canSubmit else {
            throw WalletError.transferRejected("the transfer is not ready to send.")
        }
        let store = store
        let outcome = store.scenario.transferOutcome
        let quick = store.scenario.latency.seconds.upperBound == 0
        return AsyncThrowingStream { continuation in
            let task = Task {
                func wait(_ seconds: Double) async throws {
                    try await Task.sleep(for: .seconds(quick ? 0.01 : seconds))
                }
                do {
                    try await wait(0.5)
                    continuation.yield(.signed)
                    try await wait(0.7)
                    let transfer = await store.beginTransfer(request, fee: preparation.fee)
                    let chain = PreviewCatalog.chain(request.assetID.chainID)
                    continuation.yield(.broadcast(hash: transfer.hash, explorerURL: chain?.explorer?.transactionURL(hash: transfer.hash)))
                    if outcome == .stallsAfterBroadcast {
                        try await Task.sleep(for: .seconds(86_400))
                    }
                    try await wait(1.8)
                    if outcome == .outcomeUnknownAfterBroadcast {
                        // The transfer stays pending in the history: nobody knows how it ended.
                        continuation.yield(.outcomeUnknown(reason: "The connection to the node was lost before the transfer was confirmed."))
                        continuation.finish()
                        return
                    }
                    if outcome == .failsAtInclusion {
                        await store.finishTransfer(id: transfer.id, request: request, fee: preparation.fee, success: false)
                        continuation.yield(.failed(reason: "The network included the transfer but it failed: the balance changed before it ran."))
                        continuation.finish()
                        return
                    }
                    continuation.yield(.included(blockHash: PreviewSampleData.fakeHash(transfer.hash.count + 7)))
                    if outcome == .stallsAfterInclusion {
                        try await Task.sleep(for: .seconds(86_400))
                    }
                    try await wait(2.4)
                    await store.finishTransfer(id: transfer.id, request: request, fee: preparation.fee, success: true)
                    continuation.yield(.finalized)
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
