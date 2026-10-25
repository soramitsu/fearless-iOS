import Foundation

struct SolanaBlockhashValidity: Equatable {
    let context: SolanaRpcContext
    let isValid: Bool
}

struct SolanaSignatureStatusObservation: Equatable {
    /// A context-free test/custom client can establish a positive status, never absence.
    let context: SolanaRpcContext?
    let status: SolanaSignatureStatus?
}

extension ParsedSolanaTransaction {
    /// A durable nonce uses the first System Program AdvanceNonceAccount instruction.
    /// Unknown address-table programs also cannot establish recent-blockhash expiry.
    var allowsRecentBlockhashExpiry: Bool {
        guard let index = firstInstructionProgramIndex,
              accountKeys.indices.contains(index), let data = firstInstructionData else { return false }
        return accountKeys[index] != "11111111111111111111111111111111" ||
            !data.starts(with: [4, 0, 0, 0])
    }
}

extension SolanaRpcClientProtocol {
    func signatureStatusObservation(
        _ signature: String, rpcURL: String?
    ) async throws -> SolanaSignatureStatusObservation {
        let status = try await signatureStatuses(
            [signature], searchTransactionHistory: true, rpcURL: rpcURL
        ).first ?? nil
        return SolanaSignatureStatusObservation(context: nil, status: status)
    }

    func blockhashValidity(
        _: String, minContextSlot _: Int64?, rpcURL _: String?
    ) async throws -> SolanaBlockhashValidity {
        throw SolanaRpcClientError.invalidBlockhashResponse
    }

    func finalizedBlockhash(slot _: Int64, rpcURL _: String?) async throws -> String? {
        throw SolanaRpcClientError.invalidBlockhashResponse
    }

    func resolveSignature(
        _ signature: String,
        transaction: ParsedSolanaTransaction,
        blockhashContextSlot: Int64?,
        rpcURL: String?
    ) async throws -> SolanaSignatureResolution {
        try await resolveSignatureOnOneNode(
            signature, transaction: transaction, blockhashContextSlot: blockhashContextSlot, rpcURL: rpcURL
        )
    }

    /// Stored height and slot are not signed. Expiry instead requires the signed blockhash
    /// in a freshly read finalized block, followed by invalidity at a later finalized bank
    /// and a sufficiently current absent status. These are RPC assertions, not a consensus proof,
    /// and this node's alone: the expiry names its one host.
    func resolveSignatureOnOneNode(
        _ signature: String,
        transaction: ParsedSolanaTransaction,
        blockhashContextSlot: Int64?,
        rpcURL: String?
    ) async throws -> SolanaSignatureResolution {
        let initial = try await signatureStatusObservation(signature, rpcURL: rpcURL)
        if let status = initial.status, status.isConfirmed { return .landed(status) }
        guard initial.status == nil, transaction.allowsRecentBlockhashExpiry else { return .pending }

        // A quote's bank slot is only a lookup hint; last_blockhash may belong elsewhere.
        // Missing, pruned, skipped, or different blocks cannot justify deleting the record.
        var provenSlot: Int64?
        if let hint = blockhashContextSlot, hint >= 0 {
            do {
                if try await finalizedBlockhash(slot: hint, rpcURL: rpcURL) == transaction.recentBlockhash {
                    provenSlot = hint
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                return .pending
            }
        }

        let validity = try await blockhashValidity(
            transaction.recentBlockhash, minContextSlot: provenSlot, rpcURL: rpcURL
        )
        guard !validity.isValid, let provenSlot, validity.context.slot > provenSlot else { return .pending }
        let final = try await signatureStatusObservation(signature, rpcURL: rpcURL)
        if let status = final.status, status.isConfirmed { return .landed(status) }
        guard final.status == nil, let observedSlot = final.context?.slot,
              observedSlot >= validity.context.slot else { return .pending }
        try Task.checkCancellation()
        return .expired(provingHosts: [SolanaRpcEndpoints.expiryWitnessHost(for: rpcURL)])
    }
}
