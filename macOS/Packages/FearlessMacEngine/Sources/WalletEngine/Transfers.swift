import BigInt
import Foundation
import IrohaCrypto
import SSFCrypto
import SSFModels
import SSFUtils
import WalletCore

/// Fee withdrawal must succeed before the call executes, even for an allow-death transfer.
struct TransferCapacity {
    let maximum: BigUInt
    let insufficientFee: Bool
    init(balance: Funds, native: Funds, fee: BigUInt, request: TransferRequest, preserveAsset: Bool) {
        let nativeAmount = request.assetID.isNative ? BigUInt(request.amount.units) ?? 0 : 0
        let nativeCost = request.assetID.isNative ? fee : 0
        let transferable = preserveAsset ? balance.preserved : balance.transferable
        let canWithdrawFee = native.preserved >= fee
        maximum = canWithdrawFee && transferable >= nativeCost ? transferable - nativeCost : 0
        insufficientFee = !canWithdrawFee ||
            (native.transferable >= nativeAmount && native.transferable - nativeAmount < fee)
    }
}

enum Quote {
    case substrate(SubstrateRuntime, ExtrinsicBuilder, WalletCore.CryptoType, BigUInt, MortalTransfer)
    case evm(EVMTransfer)
    var cost: BigUInt {
        switch self { case let .substrate(_, _, _, fee, _): return fee; case let .evm(tx): return tx.cost }
    }
}

struct FeeReview {
    let id = UUID()
    let quote: Quote
    let expires: ContinuousClock.Instant
}

extension NetworkServices: TransferServicing {
    func validateRecipient(_ address: String, on chainID: ChainID) -> RecipientValidation {
        guard let chain = try? Catalog.chain(chainID) else { return .invalid(reason: "Unknown network.") }
        return WalletKeys.validate(address, on: chain)
    }

    private func substrateQuote(
        _ req: TransferRequest,
        chain: Catalog.Network,
        sender: String,
        type: WalletCore.CryptoType,
        amount: BigUInt,
        block: String
    ) async throws -> Quote {
        guard let prefix = chain.prefix, amount.bitWidth <= 128 else { throw WalletError.unsupportedAsset }
        let rt = try await runtime(chain.id, block: block)
        guard let header = try await rpc(chain.id, "chain_getHeader", [block]) as? [String: Any],
              let number = header["number"], let height = try UInt64(exactly: Self.quantity(number)) else {
            throw WalletError.network("Missing block height.")
        }
        let index = try await rpc(chain.id, "system_accountNextIndex", [sender])
        let nonce: UInt32?
        if let text = index as? String, text.hasPrefix("0x") {
            nonce = UInt32(text.dropFirst(2), radix: 16)
        } else {
            nonce = index as? UInt32
        }
        guard let nonce else { throw WalletError.network("Invalid account nonce.") }
        let ss58 = SS58AddressFactory()
        let builder = try rt.builder(
            dest: ss58.accountId(fromAddress: req.recipient, type: prefix),
            asset: req.assetID,
            amount: amount,
            keepAlive: req.keepAlive,
            context: .init(
                sender: ss58.accountId(fromAddress: sender, type: prefix),
                nonce: nonce,
                height: height,
                block: block
            )
        )
        let tx = try rt.encode(builder, crypto: type, signature: Data(repeating: 0, count: type == .ecdsa ? 65 : 64))
        let hex = tx.toHex(includePrefix: true)
        let fee: BigUInt
        if let info = try? await rpc(chain.id, "payment_queryInfo", [hex, block]) as? [String: Any],
           let str = info["partialFee"] as? String, let result = BigUInt(str) {
            fee = result
        } else {
            // Modern nodes expose TransactionPaymentApi through state_call. SCALE query_info returns
            // WeightV2, DispatchClass, then Balance (u128 on the five supported Substrate networks).
            var length = UInt32(tx.count).littleEndian
            let input = tx + withUnsafeBytes(of: &length) { Data($0) }
            guard let raw = try await rpc(
                chain.id,
                "state_call",
                ["TransactionPaymentApi_query_info", input.toHex(includePrefix: true), block]
            ) as? String else {
                throw WalletError.network("No transaction payment API.")
            }
            let data = try Data(hexStringSSF: raw)
            let decoder = try ScaleDecoder(data: data)
            _ = try BigUInt(scaleDecoder: decoder)
            _ = try BigUInt(scaleDecoder: decoder)
            let dispatch = try UInt8(scaleDecoder: decoder)
            guard dispatch <= 2, decoder.remained == 16 else { throw WalletError.network("Unexpected fee format.") }
            fee = BigUInt(Data(data.suffix(16).reversed()))
        }
        return .substrate(rt, builder, type, fee, MortalTransfer(nonce: nonce, birth: height))
    }

    private func evaluate(_ req: TransferRequest, review: FeeReview? = nil) async -> (TransferPreparation, Result<Quote, WalletError>) {
        var result = TransferPreparation(request: req, fee: nil, issues: [], maxSendable: nil)
        do {
            let chain = try Catalog.chain(req.assetID.chainID)
            guard let token = chain.assets.first(where: { $0.key == req.assetID.key }), let native = chain.assets.first,
                  req.amount.decimals == token.decimals,
                  let amount = BigUInt(req.amount.units) else { throw WalletError.unsupportedAsset }
            let wallet = try await store.wallet(req.walletID)
            if wallet.isWatchOnly {
                result.issues.append(.watchOnlyWallet)
            }
            let sender = try await store.address(of: req.walletID, on: chain.id)
            if amount.isZero {
                result.issues.append(.amountIsZero)
            }
            // An incomplete draft still gets a fee and a maximum (quoted as a
            // transfer to the sender's own address); the issue names what is missing.
            let dest: String
            let recipientIsValid: Bool
            switch validateRecipient(req.recipient, on: chain.id) {
            case let .valid(normalized):
                dest = normalized
                recipientIsValid = true
            case .empty:
                result.issues.append(.invalidRecipient("Enter a recipient address."))
                dest = sender
                recipientIsValid = false
            case let .invalid(reason), let .wrongNetwork(reason):
                result.issues.append(.invalidRecipient(reason))
                dest = sender
                recipientIsValid = false
            }
            if recipientIsValid, sender == dest {
                result.issues.append(.recipientIsSender)
            }
            var normalized = req
            normalized.recipient = dest
            let block = chain.prefix != nil ? try await blockHash(chain.id) : nil
            let balance = try await funds(req.assetID, address: sender, at: block)
            result.maxSendable = try Self.amount(balance.transferable, decimals: token.decimals)
            if amount > balance.transferable, let available = result.maxSendable {
                result.issues.append(.insufficientBalance(available: available))
            }
            // Quote with an amount the account holds, so gas estimation does not revert.
            let quotedAmount = min(amount, balance.transferable)
            let quote: Quote
            if let block, recipientIsValid, amount < balance.minimum {
                let recipient = try await funds(req.assetID, address: dest, at: block)
                if !amount.isZero,
                   req.assetID.isNative ? recipient.free + amount < balance.minimum : !recipient.exists {
                    try result.issues.append(.belowExistentialDeposit(minimum: Self.amount(
                        balance.minimum,
                        decimals: token.decimals
                    )))
                }
            }

            func freshQuote(_ quantity: BigUInt) async throws -> Quote {
                if let block, let account = wallet.account(for: .substrate) {
                    return try await substrateQuote(
                        normalized,
                        chain: chain,
                        sender: sender,
                        type: account.cryptoType,
                        amount: quantity,
                        block: block
                    )
                }
                return try await .evm(evmQuote(normalized, chain: chain, sender: sender, amount: quantity))
            }

            if let review, case let .evm(tx) = review.quote {
                quote = try await .evm(refresh(tx, chain: chain.id, sender: sender))
            } else {
                quote = try await freshQuote(quotedAmount)
                if let review, quote.cost > review.quote.cost {
                    throw WalletError.transferRejected("The current fee exceeds the reviewed fee. Review again.")
                }
            }
            let fee = try Self.amount(quote.cost, decimals: native.decimals)
            result.fee = FeeEstimate(assetID: .native(chain.id), amount: fee)
            let feeBalance = req.assetID.isNative ? balance : try await funds(
                .native(chain.id),
                address: sender,
                at: block
            )
            let keep = chain.prefix != nil && (req.keepAlive || !req.assetID.isNative)
            let capacity = TransferCapacity(
                balance: balance,
                native: feeBalance,
                fee: quote.cost,
                request: req,
                preserveAsset: keep
            )
            if capacity.insufficientFee {
                result.issues.append(.insufficientBalanceForFee(fee: fee))
            }
            let cost = req.assetID.isNative ? quote.cost : 0
            if review == nil, capacity.maximum > 0 {
                let candidateFee = capacity.maximum == quotedAmount ? quote.cost : try? await freshQuote(capacity.maximum).cost
                if let candidateFee {
                    let bufferedFee = candidateFee + (candidateFee + 19) / 20
                    let conservative = TransferCapacity(
                        balance: balance,
                        native: feeBalance,
                        fee: bufferedFee,
                        request: req,
                        preserveAsset: keep
                    )
                    result.maxSendable = try Self.amount(min(capacity.maximum, conservative.maximum), decimals: token.decimals)
                } else {
                    result.maxSendable = nil
                }
            } else {
                result.maxSendable = try Self.amount(capacity.maximum, decimals: token.decimals)
            }
            if keep, amount + cost > balance.preserved, amount + cost <= balance.transferable {
                try result.issues.append(.wouldReapSender(minimumRemaining: Self.amount(
                    balance.minimum,
                    decimals: token.decimals
                )))
            }
            return (result, .success(quote))
        } catch {
            let failure = error as? WalletError ?? .network("Could not prepare transfer.")
            result.issues.append(failure == .unsupportedAsset ? .unsupportedAsset : .network(failure.localizedDescription))
            result.maxSendable = nil
            return (result, .failure(failure))
        }
    }

    func prepare(_ request: TransferRequest) async -> TransferPreparation {
        let (result, quote) = await evaluate(request)
        reviewedFees = reviewedFees.filter { $0.value.expires > .now }
        if result.canSubmit, case let .success(quote) = quote {
            reviewedFees[request] = FeeReview(quote: quote, expires: .now.advanced(by: .seconds(180)))
        } else {
            reviewedFees[request] = nil
        }
        return result
    }

    func submit(
        _ request: TransferRequest,
        approval: UserApproval
    ) async throws -> AsyncThrowingStream<TransferProgress, Error> {
        let id = request.assetID.chainID
        let slot = request.walletID.description + "/" + id.rawValue
        let owner = try await store.beginTransfer(slot)
        do {
            guard let reviewed = reviewedFees[request], reviewed.expires > .now else {
                throw WalletError.transferRejected("Review this transfer for a current fee quote.")
            }
            let (prepared, result) = await evaluate(request, review: reviewed)
            let quote = try result.get()
            guard prepared.canSubmit else {
                throw WalletError.transferRejected("Review the transfer issues before submitting.")
            }
            if case .substrate = quote, let selected = await selectedNode(for: id), selected.url.scheme != "wss" {
                throw WalletError.network("Select a secure WebSocket node to submit on this network.")
            }
            let mortality: MortalTransfer?
            let bytes: Data
            let hash: String
            switch quote {
            case let .substrate(rt, builder, type, _, mortal):
                mortality = mortal
                let sig = try await store.sign(
                    rt.payload(builder),
                    walletID: request.walletID,
                    ecosystem: .substrate,
                    approval: approval
                )
                bytes = try rt.encode(builder, crypto: type, signature: sig)
                hash = try bytes.blake2b32().toHex(includePrefix: true)
            case let .evm(tx):
                mortality = nil
                let sig = try await store.sign(
                    tx.encode(),
                    walletID: request.walletID,
                    ecosystem: .evm,
                    approval: approval
                )
                bytes = try tx.encode(signature: sig)
                hash = try bytes.keccak256().toHex(includePrefix: true)
            }
            let chain = try Catalog.chain(id)
            let item = ActivityItem(
                id: id.rawValue + "/" + hash,
                walletID: request.walletID,
                assetID: request.assetID,
                direction: .outgoing,
                counterparty: request.recipient,
                amount: request.amount,
                fee: prepared.fee?.amount,
                timestamp: Date(),
                status: .pending,
                hash: hash,
                explorerURL: chain.explorer?.transactionURL(hash: hash)
            )
            guard reviewed.expires > .now, reviewedFees[request]?.id == reviewed.id else {
                throw WalletError.transferRejected("The fee review expired or changed. Review the transfer again.")
            }
            reviewedFees[request] = nil
            try await store.record(item, mortality: mortality)
            let pair = AsyncThrowingStream<TransferProgress, Error>.makeStream()
            pair.continuation.yield(.signed)
            // Finish tracking even if the view that requested the send is dismissed.
            Task {
                do {
                    let fee = try await broadcast(bytes, item: item, chain: chain, updates: pair.continuation) {
                        await self.store.endTransfer(slot, owner: owner)
                    }
                    _ = try? await store.update(item, status: .success, actualFee: fee)
                    pair.continuation.yield(.finalized)
                } catch let unsent as SubmissionNotSent {
                    try? await store.discardUnsent(item)
                    await store.endTransfer(slot, owner: owner)
                    pair.continuation.finish(throwing: unsent.reason)
                    return
                } catch {
                    if case WalletError.transferRejected = error {
                        _ = try? await store.update(item, status: .failed)
                        pair.continuation.yield(.failed(reason: error.localizedDescription))
                    } else {
                        pair.continuation.yield(.outcomeUnknown(reason: error.localizedDescription))
                    }
                }
                await store.endTransfer(slot, owner: owner)
                pair.continuation.finish()
            }
            return pair.stream
        } catch { await store.endTransfer(slot, owner: owner); throw error }
    }
}
