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
            recentBlockhash: blockhash.value.blockhash
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
            try await requireSufficientSolBalance(
                wallet: account.address,
                requiredLamports: try Self.addUnsignedLamports(request.lamports, fee)
            )
        }

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
            associatedTokenAccountInstruction: request.associatedTokenAccountInstruction
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

    private func requireSufficientSolBalance(
        wallet: String,
        requiredLamports: String
    ) async throws {
        guard let balanceProvider else {
            return
        }

        let balances = try await balanceProvider.balances(wallet: wallet)
        guard Self.compareUnsignedDecimal(balances.nativeBalance.amount, requiredLamports) != .orderedAscending else {
            throw SolanaSendServiceError.insufficientSolBalance
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
        validateBalance: Bool = true
    ) {
        self.mnemonic = mnemonic
        self.recipientAddress = recipientAddress
        self.lamports = lamports
        self.passphrase = passphrase
        self.derivationPath = derivationPath
        self.commitment = commitment
        self.rpcURL = rpcURL
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
        validateBalance: Bool = true
    ) {
        self.mnemonic = mnemonic
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
