import Foundation

final class SolanaSendService {
    private let rpcClient: SolanaRpcClientProtocol
    private let balanceProvider: SolanaSendBalanceProvider?

    init(
        rpcClient: SolanaRpcClientProtocol,
        balanceProvider: SolanaSendBalanceProvider? = nil
    ) {
        self.rpcClient = rpcClient
        self.balanceProvider = balanceProvider
    }

    func prepare(_ request: SolanaSendRequest) async throws -> SolanaPreparedTransferTransaction {
        try SolanaTransferTransactionBuilder.requireLamports(request.lamports)
        _ = try SolanaTransferTransactionBuilder.normalizeRecipientAddress(request.recipientAddress)

        let account: SolanaAccount
        do {
            account = try SolanaKeyDerivation.deriveAccount(
                mnemonic: request.mnemonic,
                passphrase: request.passphrase,
                derivationPath: request.derivationPath
            )
        } catch {
            throw SolanaSendServiceError.invalidAccount
        }

        let blockhash = try await rpcClient.latestBlockhash(
            commitment: request.commitment,
            rpcURL: request.rpcURL
        )
        let unsigned = try SolanaTransferTransactionBuilder.buildNativeTransfer(
            senderAddress: account.address,
            recipientAddress: request.recipientAddress,
            lamports: request.lamports,
            recentBlockhash: blockhash.value.blockhash,
            computeBudget: request.computeBudget
        )
        let feeResponse = try await rpcClient.feeForMessage(
            unsigned.messageBase64,
            commitment: request.commitment,
            rpcURL: request.rpcURL
        )
        let fee = feeResponse.value

        guard let fee else {
            throw SolanaSendServiceError.feeUnavailable
        }

        if request.validateBalance {
            let balance = try await requireSufficientSolBalance(
                wallet: account.address,
                requiredLamports: try Self.addUnsignedLamports(request.lamports, fee)
            )
            if let rentRules = request.rentRules, let balance {
                try Self.checkRentRules(
                    rentRules,
                    lamports: request.lamports,
                    feeLamports: fee,
                    senderBalance: balance
                )
            }
        }

        try await rpcClient.verifyCluster(rpcURL: request.rpcURL)
        try SolanaSendAuthorization.requireCurrent()
        let signed = try SolanaTransactionSigner.signSerializedTransaction(
            mnemonic: request.mnemonic,
            transactionBase64: unsigned.transactionBase64,
            expectedSigner: account.address,
            derivationPath: request.derivationPath,
            passphrase: request.passphrase
        )
        let simulation: SolanaSimulationResponse?
        if request.simulateBeforeSend {
            let response = try await rpcClient.simulateTransaction(
                signed.signedTransactionBase64,
                options: request.simulationOptions,
                rpcURL: request.rpcURL
            )
            if response.value.errorJSON != nil {
                throw SolanaSendServiceError.simulationFailed
            }
            simulation = response
        } else {
            simulation = nil
        }

        return SolanaPreparedTransferTransaction(
            blockhash: blockhash,
            feeLamports: fee,
            signed: signed,
            simulation: simulation,
            unsigned: unsigned
        )
    }

    func send(_ request: SolanaSendRequest) async throws -> SolanaSentTransferTransaction {
        let prepared = try await prepare(request)
        let signature = try await rpcClient.sendRawTransaction(
            prepared.signed.signedTransactionBase64,
            options: request.broadcastOptions,
            rpcURL: request.rpcURL
        )

        guard signature == prepared.signed.signatureBase58 else {
            throw SolanaSendServiceError.broadcastSignatureMismatch
        }

        return SolanaSentTransferTransaction(
            prepared: prepared,
            signature: signature
        )
    }

    func prepareTokenTransfer(_ request: SolanaTokenSendRequest) async throws -> SolanaPreparedTokenTransferTransaction {
        let account: SolanaAccount
        do {
            account = try SolanaKeyDerivation.deriveAccount(
                mnemonic: request.mnemonic,
                passphrase: request.passphrase,
                derivationPath: request.derivationPath
            )
        } catch {
            throw SolanaSendServiceError.invalidAccount
        }

        try validateToken2022TransferPolicy(request)

        let blockhash = try await rpcClient.latestBlockhash(
            commitment: request.commitment,
            rpcURL: request.rpcURL
        )
        let destinationAssociatedTokenAccount: String?
        if let destinationWalletAddress = request.destinationWalletAddress {
            let associated = try SolanaTransferTransactionBuilder.deriveAssociatedTokenAccountAddress(
                walletAddress: destinationWalletAddress,
                mintAddress: request.mintAddress,
                tokenProgram: request.tokenProgram
            )
            if let requestedDestination = request.destinationTokenAccount?.trimmingCharacters(in: .whitespacesAndNewlines),
               !requestedDestination.isEmpty,
               requestedDestination != associated {
                throw SolanaTransferTransactionError.invalidAssociatedTokenAccount
            }
            destinationAssociatedTokenAccount = associated
        } else {
            destinationAssociatedTokenAccount = nil
        }
        let destinationAssociatedTokenAccountExists: Bool
        if let destinationAssociatedTokenAccount {
            destinationAssociatedTokenAccountExists = try await rpcClient.accountExists(
                address: destinationAssociatedTokenAccount,
                commitment: request.commitment,
                rpcURL: request.rpcURL
            )
        } else {
            destinationAssociatedTokenAccountExists = false
        }
        let unsigned = try SolanaTransferTransactionBuilder.buildTokenSendChecked(
            ownerAddress: account.address,
            sourceTokenAccount: request.sourceTokenAccount,
            destinationTokenAccount: destinationAssociatedTokenAccountExists
                ? destinationAssociatedTokenAccount
                : request.destinationTokenAccount,
            mintAddress: request.mintAddress,
            rawAmount: request.rawAmount,
            decimals: request.decimals,
            recentBlockhash: blockhash.value.blockhash,
            tokenProgram: request.tokenProgram,
            extraAccounts: request.extraAccounts,
            destinationWalletAddress: destinationAssociatedTokenAccountExists
                ? nil
                : request.destinationWalletAddress,
            associatedTokenAccountInstruction: request.associatedTokenAccountInstruction,
            computeBudget: request.computeBudget
        )
        let feeResponse = try await rpcClient.feeForMessage(
            unsigned.messageBase64,
            commitment: request.commitment,
            rpcURL: request.rpcURL
        )
        let fee = feeResponse.value

        guard let fee else {
            throw SolanaSendServiceError.feeUnavailable
        }

        if request.validateBalance {
            let rentLamports: Int64
            if unsigned.createsDestinationAssociatedTokenAccount, balanceProvider != nil {
                rentLamports = try await rpcClient.minimumBalanceForRentExemption(
                    dataLength: Self.solanaTokenAccountDataLength,
                    commitment: request.commitment,
                    rpcURL: request.rpcURL
                )
            } else {
                rentLamports = 0
            }
            try await requireSufficientTokenTransferBalance(
                wallet: account.address,
                request: request,
                requiredNativeLamports: try Self.addUnsignedLamports(fee, rentLamports)
            )
        }

        try await rpcClient.verifyCluster(rpcURL: request.rpcURL)
        try SolanaSendAuthorization.requireCurrent()
        let signed = try SolanaTransactionSigner.signSerializedTransaction(
            mnemonic: request.mnemonic,
            transactionBase64: unsigned.transactionBase64,
            expectedSigner: account.address,
            derivationPath: request.derivationPath,
            passphrase: request.passphrase
        )
        let simulation: SolanaSimulationResponse?
        if request.simulateBeforeSend {
            let response = try await rpcClient.simulateTransaction(
                signed.signedTransactionBase64,
                options: request.simulationOptions,
                rpcURL: request.rpcURL
            )
            if response.value.errorJSON != nil {
                throw SolanaSendServiceError.simulationFailed
            }
            simulation = response
        } else {
            simulation = nil
        }

        return SolanaPreparedTokenTransferTransaction(
            blockhash: blockhash,
            feeLamports: fee,
            signed: signed,
            simulation: simulation,
            unsigned: unsigned
        )
    }

    func sendTokenTransfer(_ request: SolanaTokenSendRequest) async throws -> SolanaSentTokenTransferTransaction {
        let prepared = try await prepareTokenTransfer(request)
        let signature = try await rpcClient.sendRawTransaction(
            prepared.signed.signedTransactionBase64,
            options: request.broadcastOptions,
            rpcURL: request.rpcURL
        )

        guard signature == prepared.signed.signatureBase58 else {
            throw SolanaSendServiceError.broadcastSignatureMismatch
        }

        return SolanaSentTokenTransferTransaction(
            prepared: prepared,
            signature: signature
        )
    }

    /// Returns the SOL balance it checked, when a balance provider is configured.
    @discardableResult
    private func requireSufficientSolBalance(
        wallet: String,
        requiredLamports: String
    ) async throws -> Int64? {
        guard let balanceProvider else {
            return nil
        }

        let balances = try await balanceProvider.balances(wallet: wallet)
        guard Self.compareUnsignedDecimal(balances.nativeBalance.amount, requiredLamports) != .orderedAscending else {
            throw SolanaSendServiceError.insufficientSolBalance
        }

        return Int64(balances.nativeBalance.amount)
    }

    /// Solana refuses a transfer that opens an account with less than the rent-exempt minimum
    /// or leaves the sender with more than zero but less than it. Both would only fail in
    /// simulation with a generic error, so they are refused here with the reason.
    static func checkRentRules(
        _ rules: SolanaRentRules,
        lamports: Int64,
        feeLamports: Int64,
        senderBalance: Int64
    ) throws {
        if !rules.recipientExists, lamports < rules.rentExemptMinimumLamports {
            throw SolanaTransferRefusal.amountBelowNewAccountMinimum(
                minimumLamports: rules.rentExemptMinimumLamports
            )
        }

        let spent = lamports.addingReportingOverflow(feeLamports)
        guard !spent.overflow, spent.partialValue <= senderBalance else {
            throw SolanaSendServiceError.insufficientSolBalance
        }
        let remainder = senderBalance - spent.partialValue
        if remainder > 0, remainder < rules.rentExemptMinimumLamports {
            throw SolanaTransferRefusal.remainderBelowAccountMinimum(
                minimumLamports: rules.rentExemptMinimumLamports
            )
        }
    }

    private func requireSufficientTokenTransferBalance(
        wallet: String,
        request: SolanaTokenSendRequest,
        requiredNativeLamports: String
    ) async throws {
        guard let balanceProvider else {
            return
        }

        let balances = try await balanceProvider.balances(wallet: wallet)
        guard Self.compareUnsignedDecimal(balances.nativeBalance.amount, requiredNativeLamports) != .orderedAscending else {
            throw SolanaSendServiceError.insufficientSolBalance
        }
        guard let tokenBalance = balances.tokenBalances.first(where: {
            $0.tokenAccountId == request.sourceTokenAccount && $0.contractAddress == request.mintAddress
        }) else {
            throw SolanaSendServiceError.insufficientTokenBalance
        }
        guard tokenBalance.decimals == request.decimals else {
            throw SolanaSendServiceError.tokenBalanceMismatch
        }
        guard Self.compareUnsignedDecimal(tokenBalance.amount, String(request.rawAmount)) != .orderedAscending else {
            throw SolanaSendServiceError.insufficientTokenBalance
        }
    }

    private func validateToken2022TransferPolicy(_ request: SolanaTokenSendRequest) throws {
        guard let metadata = request.tokenMetadata else {
            return
        }
        guard metadata.exists, metadata.mint == request.mintAddress else {
            throw SolanaSendServiceError.tokenMetadataMismatch
        }

        let expectedProgramName: String
        switch request.tokenProgram {
        case .splToken:
            expectedProgramName = "spl-token"
        case .token2022:
            expectedProgramName = "token-2022"
        }
        guard metadata.program == expectedProgramName,
              metadata.programId.map({ $0 == request.tokenProgram.programAddress }) != false else {
            throw SolanaSendServiceError.tokenMetadataMismatch
        }
        guard request.tokenProgram == .token2022 else {
            return
        }

        let extensions = Set(metadata.extensions ?? [])
        if extensions.contains("nonTransferable") {
            throw SolanaSendServiceError.unsupportedToken2022Extension
        }
        if metadata.transferFeeConfig != nil || extensions.contains("transferFeeConfig"),
           !request.acknowledgeToken2022TransferFee {
            throw SolanaSendServiceError.token2022TransferFeeNotAcknowledged
        }
        if metadata.transferHook != nil || extensions.contains("transferHook"), request.extraAccounts.isEmpty {
            throw SolanaSendServiceError.token2022TransferHookAccountsMissing
        }
    }

    private static func compareUnsignedDecimal(_ left: String, _ right: String) -> ComparisonResult {
        let normalizedLeft = normalizeUnsignedDecimal(left)
        let normalizedRight = normalizeUnsignedDecimal(right)

        guard let normalizedLeft, let normalizedRight else {
            return .orderedAscending
        }
        if normalizedLeft.count != normalizedRight.count {
            return normalizedLeft.count < normalizedRight.count ? .orderedAscending : .orderedDescending
        }
        if normalizedLeft == normalizedRight {
            return .orderedSame
        }

        return normalizedLeft < normalizedRight ? .orderedAscending : .orderedDescending
    }

    private static func normalizeUnsignedDecimal(_ value: String) -> String? {
        guard value.range(of: #"^(0|[1-9][0-9]*)$"#, options: .regularExpression) != nil else {
            return nil
        }

        return value
    }

    private static func addUnsignedLamports(_ left: Int64, _ right: Int64) throws -> String {
        guard left >= 0, right >= 0 else {
            throw SolanaSendServiceError.feeUnavailable
        }

        let added = left.addingReportingOverflow(right)
        guard added.overflow else {
            return String(added.partialValue)
        }

        return addUnsignedDecimal(String(left), String(right))
    }

    private static func addUnsignedDecimal(_ left: String, _ right: String) -> String {
        var leftDigits = left.reversed().map { Int(String($0))! }
        var rightDigits = right.reversed().map { Int(String($0))! }
        let maxCount = max(leftDigits.count, rightDigits.count)
        leftDigits += Array(repeating: 0, count: maxCount - leftDigits.count)
        rightDigits += Array(repeating: 0, count: maxCount - rightDigits.count)

        var carry = 0
        var result: [Int] = []
        for index in 0 ..< maxCount {
            let sum = leftDigits[index] + rightDigits[index] + carry
            result.append(sum % 10)
            carry = sum / 10
        }
        if carry > 0 {
            result.append(carry)
        }

        return result.reversed().map(String.init).joined()
    }

    private static let solanaTokenAccountDataLength = 165
}

/// What the chain says about rent for a native transfer: the rent-exempt minimum of an empty
/// account and whether the recipient's account already exists.
struct SolanaRentRules: Equatable {
    let rentExemptMinimumLamports: Int64
    let recipientExists: Bool
}

struct SolanaSendRequest: Equatable {
    let mnemonic: String
    let recipientAddress: String
    let lamports: Int64
    let passphrase: String
    let derivationPath: String
    let commitment: SolanaRpcCommitment
    let rpcURL: String?
    let simulationOptions: SolanaSimulationOptions
    let broadcastOptions: SolanaBroadcastOptions
    let simulateBeforeSend: Bool
    let validateBalance: Bool
    let computeBudget: SolanaComputeBudget?
    let rentRules: SolanaRentRules?

    init(
        mnemonic: String,
        recipientAddress: String,
        lamports: Int64,
        passphrase: String = "",
        derivationPath: String = UniversalWalletDerivationPaths.solanaDefault,
        commitment: SolanaRpcCommitment = .confirmed,
        rpcURL: String? = nil,
        simulationOptions: SolanaSimulationOptions? = nil,
        broadcastOptions: SolanaBroadcastOptions? = nil,
        simulateBeforeSend: Bool = true,
        validateBalance: Bool = true,
        computeBudget: SolanaComputeBudget? = nil,
        rentRules: SolanaRentRules? = nil
    ) {
        self.mnemonic = mnemonic
        self.recipientAddress = recipientAddress
        self.lamports = lamports
        self.passphrase = passphrase
        self.derivationPath = derivationPath
        self.commitment = commitment
        self.rpcURL = rpcURL
        self.computeBudget = computeBudget
        self.rentRules = rentRules
        self.simulationOptions = simulationOptions ?? SolanaSimulationOptions(
            commitment: commitment,
            replaceRecentBlockhash: false,
            sigVerify: true
        )
        self.broadcastOptions = broadcastOptions ?? SolanaBroadcastOptions(preflightCommitment: commitment)
        self.simulateBeforeSend = simulateBeforeSend
        self.validateBalance = validateBalance
    }
}

struct SolanaPreparedTransferTransaction: Equatable {
    let blockhash: SolanaLatestBlockhashResponse
    let feeLamports: Int64
    let signed: SignedSolanaTransaction
    let simulation: SolanaSimulationResponse?
    let unsigned: SolanaUnsignedTransferTransaction
}

struct SolanaSentTransferTransaction: Equatable {
    let prepared: SolanaPreparedTransferTransaction
    let signature: String
}

struct SolanaTokenSendRequest: Equatable {
    let mnemonic: String
    let sourceTokenAccount: String
    let destinationTokenAccount: String?
    let mintAddress: String
    let rawAmount: Int64
    let decimals: Int
    let passphrase: String
    let derivationPath: String
    let commitment: SolanaRpcCommitment
    let rpcURL: String?
    let tokenProgram: SolanaTokenProgram
    let extraAccounts: [SolanaTokenTransferExtraAccount]
    let tokenMetadata: SolanaTokenMetadata?
    let acknowledgeToken2022TransferFee: Bool
    let destinationWalletAddress: String?
    let associatedTokenAccountInstruction: SolanaAssociatedTokenAccountInstruction
    let simulationOptions: SolanaSimulationOptions
    let broadcastOptions: SolanaBroadcastOptions
    let simulateBeforeSend: Bool
    let validateBalance: Bool
    let computeBudget: SolanaComputeBudget?

    init(
        mnemonic: String,
        sourceTokenAccount: String,
        destinationTokenAccount: String? = nil,
        mintAddress: String,
        rawAmount: Int64,
        decimals: Int,
        passphrase: String = "",
        derivationPath: String = UniversalWalletDerivationPaths.solanaDefault,
        commitment: SolanaRpcCommitment = .confirmed,
        rpcURL: String? = nil,
        tokenProgram: SolanaTokenProgram = .splToken,
        extraAccounts: [SolanaTokenTransferExtraAccount] = [],
        tokenMetadata: SolanaTokenMetadata? = nil,
        acknowledgeToken2022TransferFee: Bool = false,
        destinationWalletAddress: String? = nil,
        associatedTokenAccountInstruction: SolanaAssociatedTokenAccountInstruction = .createIdempotent,
        simulationOptions: SolanaSimulationOptions? = nil,
        broadcastOptions: SolanaBroadcastOptions? = nil,
        simulateBeforeSend: Bool = true,
        validateBalance: Bool = true,
        computeBudget: SolanaComputeBudget? = nil
    ) {
        self.mnemonic = mnemonic
        self.computeBudget = computeBudget
        self.sourceTokenAccount = sourceTokenAccount
        self.destinationTokenAccount = destinationTokenAccount
        self.mintAddress = mintAddress
        self.rawAmount = rawAmount
        self.decimals = decimals
        self.passphrase = passphrase
        self.derivationPath = derivationPath
        self.commitment = commitment
        self.rpcURL = rpcURL
        self.tokenProgram = tokenProgram
        self.extraAccounts = extraAccounts
        self.tokenMetadata = tokenMetadata
        self.acknowledgeToken2022TransferFee = acknowledgeToken2022TransferFee
        self.destinationWalletAddress = destinationWalletAddress
        self.associatedTokenAccountInstruction = associatedTokenAccountInstruction
        self.simulationOptions = simulationOptions ?? SolanaSimulationOptions(
            commitment: commitment,
            replaceRecentBlockhash: false,
            sigVerify: true
        )
        self.broadcastOptions = broadcastOptions ?? SolanaBroadcastOptions(preflightCommitment: commitment)
        self.simulateBeforeSend = simulateBeforeSend
        self.validateBalance = validateBalance
    }
}

struct SolanaPreparedTokenTransferTransaction: Equatable {
    let blockhash: SolanaLatestBlockhashResponse
    let feeLamports: Int64
    let signed: SignedSolanaTransaction
    let simulation: SolanaSimulationResponse?
    let unsigned: SolanaUnsignedTokenSendTransaction
}

struct SolanaSentTokenTransferTransaction: Equatable {
    let prepared: SolanaPreparedTokenTransferTransaction
    let signature: String
}

enum SolanaSendServiceError: Error, Equatable {
    case invalidAccount
    case feeUnavailable
    case simulationFailed
    case broadcastSignatureMismatch
    case insufficientSolBalance
    case insufficientTokenBalance
    case tokenBalanceMismatch
    case tokenMetadataMismatch
    case token2022TransferFeeNotAcknowledged
    case token2022TransferHookAccountsMissing
    case unsupportedToken2022Extension
}

protocol SolanaSendBalanceProvider {
    func balances(wallet: String) async throws -> SolanaBalanceSyncResult
}

final class SolanaBalanceSyncSendBalanceProvider: SolanaSendBalanceProvider {
    private let balanceSync: SolanaBalanceSync
    private let network: UniversalWalletRegistry.SolanaNetwork
    private let baseURL: String?

    init(
        balanceSync: SolanaBalanceSync,
        network: UniversalWalletRegistry.SolanaNetwork = UniversalWalletRegistry.solanaMainnet,
        baseURL: String? = nil
    ) {
        self.balanceSync = balanceSync
        self.network = network
        self.baseURL = baseURL
    }

    func balances(wallet: String) async throws -> SolanaBalanceSyncResult {
        try await balanceSync.balances(
            wallet: wallet,
            network: network,
            baseURL: baseURL,
            includeTokenMetadata: false
        )
    }
}

// MARK: - Ambiguous broadcasts

/// How long the wallet waits for a broadcast transaction to show up confirmed before it
/// answers the user. Solana confirms in about a second; the blockhash expires after roughly
/// 150 blocks (about a minute), which bounds how long an outcome can stay unknown.
struct SolanaConfirmationPolicy: Equatable {
    let timeout: TimeInterval
    let pollInterval: TimeInterval

    static let standard = SolanaConfirmationPolicy(timeout: 30, pollInterval: 1)
}

/// What became of a transfer the wallet tried to send.
enum SolanaTransferOutcome: Equatable {
    /// Confirmed on chain, or accepted by a node and still on its way (`confirmed == false`).
    case sent(signature: String, confirmed: Bool)
    /// The cluster processed it and it failed: the amount did not move, the fee was paid.
    case failedOnChain(signature: String)
    /// Nothing left the wallet, and the reason is known.
    case notSent(SolanaTransferNotSentReason)
    /// It may be with the cluster; the record stays until it lands or expires.
    case unknown(signature: String)
    /// Its blockhash expired, but too few nodes could prove it never landed
    /// (`SolanaTransactionBroadcaster.provesNotSent`). The record is released so the wallet
    /// can send again; the user checks the balance and the transaction first.
    case unverified(signature: String)
    /// The retained payment has no matching original cluster binding; no lookup or retry occurred.
    case recoveryUnavailable(signature: String)
    /// Preserved data cannot be read safely; there is no trustworthy signature to look up.
    case recoveryRecordUnreadable
}

enum SolanaTransferNotSentReason: Equatable {
    /// No Solana node could be reached.
    case noConnection
    /// Every node read the transaction and refused it.
    case rejectedByNetwork
    /// Its blockhash expired before any block included it.
    case expired(signature: String)
}

/// What an earlier transfer turned out to be when a new one was about to be signed.
enum SolanaPriorTransferState: Equatable {
    case inProgress
    /// Nothing is pending, or what was pending is settled and the user already knows.
    case clear
    case unreadableRecord
    /// It landed although the user was told its outcome was unknown.
    case sentAfterAll(signature: String)
    /// The user was told it was sent, but it expired without landing or failed on chain.
    case notSentAfterAll(signature: String)
    /// Its blockhash expired, but too few nodes could prove it never landed. The record is
    /// released; the new transfer stops so the user checks the balance and confirms again.
    case unverified(signature: String)
    /// It could still land.
    case unresolved(signature: String)
}

/// Hands a signed transaction to the cluster and finds out what became of it. While an
/// earlier transaction for the same wallet and network could still land, it signs and sends
/// nothing new; retrying only ever re-sends the same bytes, which carry the same signature
/// and can land at most once.
final class SolanaTransactionBroadcaster {
    private let rpcClient: SolanaRpcClientProtocol
    private let store: SolanaPendingBroadcastStoring
    private let expectedPayer: String
    private let policy: SolanaConfirmationPolicy
    private let now: () -> Date
    private let sleep: (TimeInterval) async throws -> Void

    init(
        rpcClient: SolanaRpcClientProtocol,
        expectedPayer: String,
        store: SolanaPendingBroadcastStoring = SolanaPendingBroadcastStore.shared,
        policy: SolanaConfirmationPolicy = .standard,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
        }
    ) {
        self.rpcClient = rpcClient
        self.store = store
        self.expectedPayer = expectedPayer
        self.policy = policy
        self.now = now
        self.sleep = sleep
    }

    /// No endpoint may supply the missing identity of a historical retained payment.
    func unavailableSignature(for scope: SolanaPendingBroadcastScope) -> String? {
        guard case let .pending(record) = recoveryState(for: scope), !isBound(record, to: scope) else { return nil }
        return record.signature
    }

    /// A synchronous retained-state check never infers clearance from an old RPC result.
    func retainedTransferState(scope: SolanaPendingBroadcastScope) -> SolanaPriorTransferState {
        do {
            guard let snapshot = try recoverySnapshot(for: scope) else { return .clear }
            return .unresolved(signature: snapshot.record.signature)
        } catch { return .unreadableRecord }
    }

    /// Settles an earlier transfer before a new one is signed, under the same attempt owner.
    func priorTransferState(
        scope: SolanaPendingBroadcastScope,
        rpcURL: String?,
        attempt supplied: SolanaSubmissionRegistry.Attempt? = nil
    ) async -> SolanaPriorTransferState {
        let registry = SolanaSubmissionRegistry.shared
        guard let attempt = supplied ?? registry.begin(scope), registry.owns(attempt, scope: scope) else {
            return .inProgress
        }
        defer { if supplied == nil { registry.end(attempt) } }
        return await resolvePriorTransfer(scope: scope, rpcURL: rpcURL)
    }

    private func resolvePriorTransfer(
        scope: SolanaPendingBroadcastScope, rpcURL: String?
    ) async -> SolanaPriorTransferState {
        let snapshot: SolanaPendingBroadcastSnapshot
        do {
            guard let value = try recoverySnapshot(for: scope) else { return .clear }
            snapshot = value
        } catch { return .unreadableRecord }
        let record = snapshot.record
        guard isBound(record, to: scope) else { return .unresolved(signature: record.signature) }
        let resolution: SolanaSignatureResolution
        do {
            resolution = try await rpcClient.resolveSignature(
                record.signature, transaction: record.validatedTransaction(for: scope),
                blockhashContextSlot: record.blockhashContextSlot, rpcURL: rpcURL
            )
        } catch { return .unresolved(signature: record.signature) }
        switch resolution {
        case let .landed(status):
            guard store.clear(snapshot, for: scope) else { return retainedAfterRejectedClear(scope: scope) }
            if status.errorJSON != nil {
                return record.reportedAsSent ? .notSentAfterAll(signature: record.signature) : .clear
            }
            return record.reportedAsSent ? .clear : .sentAfterAll(signature: record.signature)
        case let .expired(hosts):
            guard store.clear(snapshot, for: scope) else { return retainedAfterRejectedClear(scope: scope) }
            guard provesNotSent(expiryProvedBy: hosts, for: record) else {
                return .unverified(signature: record.signature)
            }
            return record.reportedAsSent ? .notSentAfterAll(signature: record.signature) : .clear
        case .pending: return .unresolved(signature: record.signature)
        }
    }

    /// Distinct hosts whose expiry proof can say a transfer was not sent.
    static let notSentWitnessCount = 2
    /// Nodes keep hours to days of history (about 9 h on api.mainnet-beta.solana.com): an older
    /// transfer can look absent on a node that has pruned its slot.
    static let notSentMaxRecordAge: TimeInterval = 6 * 60 * 60

    /// Whether an expiry proves nothing left the wallet: two distinct hosts proved it, and the
    /// record was signed less than six hours ago. A signing time in the future counts as older.
    private func provesNotSent(expiryProvedBy hosts: Set<String>, for record: SolanaPendingBroadcast) -> Bool {
        let age = now().timeIntervalSince(record.createdAt)
        return hosts.count >= Self.notSentWitnessCount && age >= 0 && age < Self.notSentMaxRecordAge
    }

    private func retainedAfterRejectedClear(scope: SolanaPendingBroadcastScope) -> SolanaPriorTransferState {
        let current = retainedTransferState(scope: scope)
        // An unexpected removal is not this attempt's acknowledged clearance.
        return current == .clear ? .inProgress : current
    }

    /// Insert-only retention precedes output. Direct callers share the service attempt gate.
    func broadcast(
        _ signed: SignedSolanaTransaction,
        lastValidBlockHeight: Int64,
        blockhashContextSlot: Int64? = nil,
        scope: SolanaPendingBroadcastScope,
        options: SolanaBroadcastOptions,
        rpcURL: String?,
        attempt supplied: SolanaSubmissionRegistry.Attempt? = nil
    ) async throws -> SolanaTransferOutcome {
        let registry = SolanaSubmissionRegistry.shared
        guard let attempt = supplied ?? registry.begin(scope), registry.owns(attempt, scope: scope) else {
            throw SolanaPendingBroadcastStoreError.submissionInProgress
        }
        defer { if supplied == nil { registry.end(attempt) } }
        if case .unreadable = recoveryState(for: scope) { return .recoveryRecordUnreadable }
        guard let genesisHash = rpcClient.expectedGenesisHash else { throw SolanaRpcClientError.unboundCluster }
        let record = SolanaPendingBroadcast(
            walletId: scope.walletId, chainId: scope.chainId, signature: signed.signatureBase58,
            transactionBase64: signed.signedTransactionBase64, lastValidBlockHeight: lastValidBlockHeight,
            createdAt: now(), reportedAsSent: false,
            genesisHash: genesisHash, blockhashContextSlot: blockhashContextSlot
        )
        guard try record.validatedTransaction(for: scope).accountKeys.first == expectedPayer else {
            throw SolanaPendingBroadcastStoreError.invalidRecord
        }
        let snapshot: SolanaPendingBroadcastSnapshot
        try SolanaSendAuthorization.requireCurrent()
        do { snapshot = try store.admit(record, for: scope) } catch SolanaPendingBroadcastStoreError.unreadableRecord {
            return .recoveryRecordUnreadable
        }
        return await send(snapshot, scope: scope, options: options, rpcURL: rpcURL, isFirstAttempt: true)
    }

    /// Re-sends only the retained bytes and cannot overlap another attempt for this scope.
    func retry(
        signature: String,
        scope: SolanaPendingBroadcastScope,
        options: SolanaBroadcastOptions,
        rpcURL: String?,
        attempt supplied: SolanaSubmissionRegistry.Attempt? = nil
    ) async -> SolanaTransferOutcome? {
        let registry = SolanaSubmissionRegistry.shared
        guard let attempt = supplied ?? registry.begin(scope), registry.owns(attempt, scope: scope) else { return nil }
        defer { if supplied == nil { registry.end(attempt) } }
        let snapshot: SolanaPendingBroadcastSnapshot
        do {
            guard let value = try recoverySnapshot(for: scope) else { return nil }
            snapshot = value
        } catch { return .recoveryRecordUnreadable }
        let record = snapshot.record
        guard record.signature == signature else { return nil }
        guard isBound(record, to: scope) else { return .recoveryUnavailable(signature: record.signature) }
        return await send(snapshot, scope: scope, options: options, rpcURL: rpcURL, isFirstAttempt: false)
    }

    private func recoverySnapshot(for scope: SolanaPendingBroadcastScope) throws -> SolanaPendingBroadcastSnapshot? {
        guard let snapshot = try store.snapshot(for: scope) else { return nil }
        guard try snapshot.record.validatedTransaction(for: scope).accountKeys.first == expectedPayer else {
            throw SolanaPendingBroadcastStoreError.unreadableRecord
        }
        return snapshot
    }

    private func recoveryState(for scope: SolanaPendingBroadcastScope) -> SolanaPendingBroadcastReadState {
        do {
            return try recoverySnapshot(for: scope).map { .pending($0.record) } ?? .absent
        } catch { return .unreadable }
    }

    private func isBound(_ record: SolanaPendingBroadcast, to scope: SolanaPendingBroadcastScope) -> Bool {
        SolanaPendingBroadcastScope(walletId: record.walletId, chainId: record.chainId) == scope &&
            record.genesisHash != nil && record.genesisHash == rpcClient.expectedGenesisHash
    }

    private func send(
        _ snapshot: SolanaPendingBroadcastSnapshot,
        scope: SolanaPendingBroadcastScope,
        options: SolanaBroadcastOptions,
        rpcURL: String?,
        isFirstAttempt: Bool
    ) async -> SolanaTransferOutcome {
        let record = snapshot.record
        let failure: SolanaBroadcastFailure
        do {
            let signature = try await rpcClient.sendRawTransaction(
                record.transactionBase64, options: options, rpcURL: rpcURL
            )
            // A node answering with some other signature proves nothing about this one.
            let accepted = signature == record.signature
            return await settle(snapshot, scope: scope, rpcURL: rpcURL, acceptedByNode: accepted)
        } catch let error as SolanaBroadcastFailure {
            failure = error
        } catch {
            failure = SolanaBroadcastFailure(attempts: [SolanaBroadcastAttemptOutcome(error: error)])
        }

        // A first attempt that no node forwarded never existed. Any later attempt is a copy of
        // something that may already be on its way, so a refusal ("already processed",
        // "blockhash not found") proves nothing and only the chain can answer.
        if isFirstAttempt, !failure.mayHaveReachedCluster {
            guard store.clear(snapshot, for: scope) else { return .unknown(signature: record.signature) }
            // A node that read the transaction and refused it says more than one that could
            // not be reached.
            return .notSent(failure.someNodeRefused ? .rejectedByNetwork : .noConnection)
        }

        return await settle(snapshot, scope: scope, rpcURL: rpcURL, acceptedByNode: false)
    }

    private func settle(
        _ snapshot: SolanaPendingBroadcastSnapshot,
        scope: SolanaPendingBroadcastScope,
        rpcURL: String?,
        acceptedByNode: Bool
    ) async -> SolanaTransferOutcome {
        let record = snapshot.record
        let deadline = now().addingTimeInterval(policy.timeout)

        repeat {
            if let resolution = try? await rpcClient.resolveSignature(
                record.signature,
                transaction: record.validatedTransaction(for: scope),
                blockhashContextSlot: record.blockhashContextSlot,
                rpcURL: rpcURL
            ) {
                switch resolution {
                case let .landed(status):
                    guard store.clear(snapshot, for: scope) else { return .unknown(signature: record.signature) }
                    return status.errorJSON == nil
                        ? .sent(signature: record.signature, confirmed: true)
                        : .failedOnChain(signature: record.signature)
                case let .expired(hosts):
                    guard store.clear(snapshot, for: scope) else { return .unknown(signature: record.signature) }
                    return provesNotSent(expiryProvedBy: hosts, for: record)
                        ? .notSent(.expired(signature: record.signature))
                        : .unverified(signature: record.signature)
                case .pending:
                    break
                }
            }

            guard now() < deadline else {
                break
            }
            do {
                try await sleep(policy.pollInterval)
            } catch {
                break
            }
        } while now() < deadline

        // A node accepted it after simulating it; it is on its way. The record stays so the
        // next transfer checks that it really landed. Never mark an unaccepted payment.
        guard acceptedByNode, (try? store.markReported(snapshot, for: scope)) == true else {
            return .unknown(signature: record.signature)
        }
        return .sent(signature: record.signature, confirmed: false)
    }
}
