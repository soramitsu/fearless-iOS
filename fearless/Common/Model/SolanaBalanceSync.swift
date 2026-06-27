import Foundation

final class SolanaBalanceSync {
    private let client: SolanaIndexerClientProtocol

    init(client: SolanaIndexerClientProtocol) {
        self.client = client
    }

    func balances(
        wallet: String,
        network: UniversalWalletRegistry.SolanaNetwork = UniversalWalletRegistry.solanaMainnet,
        baseURL: String? = nil,
        includeTokenMetadata: Bool = true
    ) async throws -> SolanaBalanceSyncResult {
        let resolvedBaseURL = baseURL ?? network.indexerBaseURL.absoluteString
        _ = try SolanaIndexerRoutes.balancesURL(wallet: wallet, baseURL: resolvedBaseURL)

        _ = try await client.verifyServiceInfo(
            baseURL: resolvedBaseURL,
            expectedChainId: network.chainId
        )
        let response = try await client.balances(wallet: wallet, baseURL: resolvedBaseURL)
        guard response.wallet == wallet else {
            throw SolanaBalanceSyncError.walletMismatch
        }
        guard response.syncedAt > 0 else {
            throw SolanaBalanceSyncError.invalidSyncTimestamp
        }

        let native = try nativeBalance(
            response.native,
            wallet: wallet,
            network: network,
            syncedAtMillis: response.syncedAt
        )
        let normalizedTokens = response.tokens.compactMap {
            tokenBalance(
                $0,
                wallet: wallet,
                network: network,
                syncedAtMillis: response.syncedAt
            )
        }
        let metadataByMint = includeTokenMetadata
            ? try await tokenMetadataByMint(normalizedTokens.map(\.source.mint), baseURL: resolvedBaseURL)
            : [:]
        let tokens = normalizedTokens.map { normalized in
            UniversalWalletIndexedAssetBalance(
                accountId: normalized.balance.accountId,
                ecosystem: normalized.balance.ecosystem,
                chainId: normalized.balance.chainId,
                assetId: normalized.balance.assetId,
                amount: normalized.balance.amount,
                decimals: normalized.balance.decimals,
                isNative: normalized.balance.isNative,
                symbol: tokenSymbol(mint: normalized.source.mint, metadata: metadataByMint[normalized.source.mint]),
                name: tokenName(mint: normalized.source.mint, metadata: metadataByMint[normalized.source.mint]),
                uiAmountString: normalized.balance.uiAmountString,
                tokenAccountId: normalized.balance.tokenAccountId,
                contractAddress: normalized.balance.contractAddress,
                tokenProgram: normalized.balance.tokenProgram,
                syncedAtMillis: normalized.balance.syncedAtMillis
            )
        }
        let allBalances = [native] + tokens

        return SolanaBalanceSyncResult(
            wallet: wallet,
            networkId: network.id,
            chainId: network.chainId,
            syncedAtMillis: response.syncedAt,
            nativeBalance: native,
            tokenBalances: tokens,
            balances: allBalances
        )
    }

    private func nativeBalance(
        _ native: SolanaNativeBalance,
        wallet _: String,
        network: UniversalWalletRegistry.SolanaNetwork,
        syncedAtMillis: Int64
    ) throws -> UniversalWalletIndexedAssetBalance {
        guard native.type == "native",
              native.mint == network.nativeAsset.id,
              Self.isUnsignedInteger(native.lamports),
              Self.decimalRange.contains(native.decimals),
              Self.isHumanText(native.uiAmountString, maxLength: 80) else {
            throw SolanaBalanceSyncError.invalidNativeBalance
        }

        let balance = UniversalWalletIndexedAssetBalance(
            accountId: network.id,
            ecosystem: .solana,
            chainId: network.chainId,
            assetId: network.nativeAsset.id,
            amount: native.lamports,
            decimals: native.decimals,
            isNative: true,
            symbol: network.nativeAsset.symbol,
            name: network.name,
            uiAmountString: native.uiAmountString,
            syncedAtMillis: syncedAtMillis
        )
        guard balance.validationErrors().isEmpty else {
            throw SolanaBalanceSyncError.invalidNativeBalance
        }

        return balance
    }

    private func tokenBalance(
        _ token: SolanaTokenBalance,
        wallet: String,
        network: UniversalWalletRegistry.SolanaNetwork,
        syncedAtMillis: Int64
    ) -> NormalizedSolanaTokenBalance? {
        guard token.type == "token",
              token.owner == wallet,
              !token.isNative,
              Self.supportedTokenPrograms.contains(token.program),
              Self.isBase58PublicKey(token.accountAddress),
              Self.isBase58PublicKey(token.mint),
              Self.isBase58PublicKey(token.programId),
              Self.isUnsignedInteger(token.amount),
              Self.decimalRange.contains(token.decimals),
              Self.isHumanText(token.uiAmountString, maxLength: 80) else {
            return nil
        }

        let balance = UniversalWalletIndexedAssetBalance(
            accountId: network.id,
            ecosystem: .solana,
            chainId: network.chainId,
            assetId: token.mint,
            amount: token.amount,
            decimals: token.decimals,
            isNative: false,
            symbol: Self.shortenMint(token.mint),
            name: token.mint,
            uiAmountString: token.uiAmountString,
            tokenAccountId: token.accountAddress,
            contractAddress: token.mint,
            tokenProgram: token.program,
            syncedAtMillis: syncedAtMillis
        )

        guard balance.validationErrors().isEmpty else {
            return nil
        }

        return NormalizedSolanaTokenBalance(source: token, balance: balance)
    }

    private func tokenMetadataByMint(
        _ mints: [String],
        baseURL: String
    ) async throws -> [String: SolanaTokenMetadata] {
        let uniqueMints = Array(Set(mints)).sorted()
        guard !uniqueMints.isEmpty else {
            return [:]
        }

        var metadataByMint: [String: SolanaTokenMetadata] = [:]
        do {
            for chunk in uniqueMints.chunked(size: SolanaIndexerRoutes.maxMetadataBatchSize) {
                let response = try await client.tokenMetadataBatch(mints: chunk, baseURL: baseURL)
                response.tokens.forEach { metadata in
                    if metadata.exists, Self.isBase58PublicKey(metadata.mint) {
                        metadataByMint[metadata.mint] = metadata
                    }
                }
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return [:]
        }

        return metadataByMint
    }

    private func tokenSymbol(mint: String, metadata: SolanaTokenMetadata?) -> String {
        Self.safeHumanText(metadata?.symbol, maxLength: 32) ?? Self.shortenMint(mint)
    }

    private func tokenName(mint: String, metadata: SolanaTokenMetadata?) -> String {
        Self.safeHumanText(metadata?.name, maxLength: 96) ?? mint
    }

    private struct NormalizedSolanaTokenBalance {
        let source: SolanaTokenBalance
        let balance: UniversalWalletIndexedAssetBalance
    }

    private static let decimalRange = 0 ... 255
    private static let supportedTokenPrograms: Set<String> = ["spl-token", "token-2022"]

    private static func isUnsignedInteger(_ value: String) -> Bool {
        matches(value, #"^(0|[1-9][0-9]*)$"#)
    }

    private static func isBase58PublicKey(_ value: String) -> Bool {
        matches(value, #"^[1-9A-HJ-NP-Za-km-z]{32,44}$"#)
    }

    private static func isHumanText(_ value: String, maxLength: Int) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return !normalized.isEmpty &&
            normalized.count <= maxLength &&
            normalized.rangeOfCharacter(from: .controlCharacters) == nil
    }

    private static func safeHumanText(_ value: String?, maxLength: Int) -> String? {
        guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              isHumanText(normalized, maxLength: maxLength) else {
            return nil
        }

        return normalized
    }

    private static func shortenMint(_ mint: String) -> String {
        guard mint.count > 12 else {
            return mint
        }

        return "\(mint.prefix(4))...\(mint.suffix(4))"
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }
}

struct SolanaBalanceSyncResult: Equatable {
    let wallet: String
    let networkId: String
    let chainId: String
    let syncedAtMillis: Int64
    let nativeBalance: UniversalWalletIndexedAssetBalance
    let tokenBalances: [UniversalWalletIndexedAssetBalance]
    let balances: [UniversalWalletIndexedAssetBalance]
}

enum SolanaBalanceSyncError: Error, Equatable {
    case walletMismatch
    case invalidSyncTimestamp
    case invalidNativeBalance
}

private extension Array {
    func chunked(size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
