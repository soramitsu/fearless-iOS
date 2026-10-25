import XCTest
@testable import fearless

final class SolanaBalanceSyncTests: XCTestCase {
    func testNormalizesNativeSOLAndTokenBalancesFromSIIntoSharedAssetBalances() async throws {
        let client = FakeSolanaIndexerClient(
            response: Self.balancesResponse(
                lamports: "2500000000",
                uiAmountString: "2.5",
                tokens: [
                    Self.tokenBalance(
                        mint: Self.splMint,
                        accountAddress: Self.tokenAccount,
                        amount: "12500000",
                        uiAmountString: "12.5",
                        decimals: 6,
                        program: "spl-token"
                    ),
                    Self.tokenBalance(
                        mint: Self.token2022Mint,
                        accountAddress: Self.token2022Account,
                        amount: "3000000001",
                        uiAmountString: "3.000000001",
                        decimals: 9,
                        program: "token-2022"
                    )
                ]
            ),
            metadata: [
                Self.tokenMetadata(mint: Self.splMint, symbol: "USDC", name: "USD Coin", program: "spl-token"),
                Self.tokenMetadata(mint: Self.token2022Mint, symbol: "T22", name: "Token 2022 Asset", program: "token-2022")
            ]
        )

        let result = try await SolanaBalanceSync(client: client).balances(wallet: Self.wallet)

        XCTAssertEqual(client.verifiedBaseURLs, ["https://si.soramitsu.io"])
        XCTAssertEqual(client.verifiedExpectedChainIds, ["solana:mainnet"])
        XCTAssertEqual(result.networkId, "solana-mainnet")
        XCTAssertEqual(result.chainId, "solana:mainnet")
        XCTAssertEqual(result.balances.count, 3)
        XCTAssertEqual(result.nativeBalance.accountId, "solana-mainnet")
        XCTAssertEqual(result.nativeBalance.assetId, "SOL")
        XCTAssertEqual(result.nativeBalance.amount, "2500000000")
        XCTAssertEqual(result.nativeBalance.uiAmountString, "2.5")
        XCTAssertTrue(result.nativeBalance.isNative)

        let spl = try XCTUnwrap(result.tokenBalances.first)
        XCTAssertEqual(spl.accountId, "solana-mainnet")
        XCTAssertEqual(spl.assetId, Self.splMint)
        XCTAssertEqual(spl.amount, "12500000")
        XCTAssertEqual(spl.uiAmountString, "12.5")
        XCTAssertEqual(spl.decimals, 6)
        XCTAssertEqual(spl.symbol, "USDC")
        XCTAssertEqual(spl.name, "USD Coin")
        XCTAssertEqual(spl.tokenAccountId, Self.tokenAccount)
        XCTAssertEqual(spl.contractAddress, Self.splMint)
        XCTAssertEqual(spl.tokenProgram, "spl-token")

        let token2022 = result.tokenBalances[1]
        XCTAssertEqual(token2022.assetId, Self.token2022Mint)
        XCTAssertEqual(token2022.symbol, "T22")
        XCTAssertEqual(token2022.name, "Token 2022 Asset")
        XCTAssertEqual(token2022.tokenProgram, "token-2022")
        XCTAssertEqual(client.metadataBatchCalls, [[Self.token2022Mint, Self.splMint].sorted()])
    }

    func testKeepsTokenBalancesWhenMetadataLookupFails() async throws {
        let client = FakeSolanaIndexerClient(
            response: Self.balancesResponse(
                lamports: "1",
                uiAmountString: "0.000000001",
                tokens: [
                    Self.tokenBalance(
                        mint: Self.splMint,
                        accountAddress: Self.tokenAccount,
                        amount: "7",
                        uiAmountString: "7",
                        decimals: 6,
                        program: "spl-token"
                    )
                ]
            ),
            metadataError: TestError.metadataUnavailable
        )

        let result = try await SolanaBalanceSync(client: client).balances(wallet: Self.wallet)

        XCTAssertEqual(result.tokenBalances.count, 1)
        XCTAssertEqual(result.tokenBalances.first?.symbol, "So11...1112")
        XCTAssertEqual(result.tokenBalances.first?.name, Self.splMint)
    }

    func testSkipsMalformedTokenBalancesWithoutHidingNativeSOL() async throws {
        let invalidOwner = Self.tokenBalance(
            mint: Self.splMint,
            accountAddress: Self.tokenAccount,
            amount: "7",
            uiAmountString: "7",
            decimals: 6,
            program: "spl-token"
        ).copy(owner: "11111111111111111111111111111111")
        let validToken = Self.tokenBalance(
            mint: Self.token2022Mint,
            accountAddress: Self.token2022Account,
            amount: "3",
            uiAmountString: "3",
            decimals: 9,
            program: "token-2022"
        )
        let client = FakeSolanaIndexerClient(
            response: Self.balancesResponse(
                lamports: "1",
                uiAmountString: "0.000000001",
                tokens: [invalidOwner, validToken]
            )
        )

        let result = try await SolanaBalanceSync(client: client).balances(wallet: Self.wallet)

        XCTAssertEqual(result.nativeBalance.amount, "1")
        XCTAssertEqual(result.tokenBalances.map(\.assetId), [Self.token2022Mint])
    }

    func testRejectsMismatchedWalletAndMalformedNativeBalances() async throws {
        do {
            _ = try await SolanaBalanceSync(
                client: FakeSolanaIndexerClient(response: Self.balancesResponse(wallet: "11111111111111111111111111111111"))
            ).balances(wallet: Self.wallet)
            XCTFail("Expected wallet mismatch to be rejected")
        } catch {
            XCTAssertEqual(error as? SolanaBalanceSyncError, .walletMismatch)
        }

        do {
            _ = try await SolanaBalanceSync(
                client: FakeSolanaIndexerClient(response: Self.balancesResponse(lamports: "-1"))
            ).balances(wallet: Self.wallet)
            XCTFail("Expected malformed native balance to be rejected")
        } catch {
            XCTAssertEqual(error as? SolanaBalanceSyncError, .invalidNativeBalance)
        }
    }

    func testRejectsMalformedWalletBeforeNetworkCalls() async throws {
        let client = FakeSolanaIndexerClient()

        do {
            _ = try await SolanaBalanceSync(client: client).balances(wallet: "../bad")
            XCTFail("Expected malformed Solana wallet to be rejected")
        } catch {
            XCTAssertEqual(error as? SolanaIndexerRouteError, .invalidWallet)
        }

        XCTAssertTrue(client.verifiedBaseURLs.isEmpty)
    }

    func testVerifiesDevnetBalancesAgainstDevnetServiceIdentity() async throws {
        let client = FakeSolanaIndexerClient(
            response: Self.balancesResponse(lamports: "1", uiAmountString: "0.000000001")
        )

        let result = try await SolanaBalanceSync(client: client).balances(
            wallet: Self.wallet,
            network: UniversalWalletRegistry.solanaDevnet,
            includeTokenMetadata: false
        )

        XCTAssertEqual(client.verifiedBaseURLs, ["https://si.soramitsu.io"])
        XCTAssertEqual(client.verifiedExpectedChainIds, ["solana:devnet"])
        XCTAssertEqual(result.networkId, "solana-devnet")
        XCTAssertEqual(result.chainId, "solana:devnet")
    }

    private final class FakeSolanaIndexerClient: SolanaIndexerClientProtocol {
        private let response: SolanaWalletBalancesResponse
        private let metadata: [SolanaTokenMetadata]
        private let metadataError: Error?
        private(set) var verifiedBaseURLs: [String] = []
        private(set) var verifiedExpectedChainIds: [String] = []
        private(set) var metadataBatchCalls: [[String]] = []

        init(
            response: SolanaWalletBalancesResponse = SolanaBalanceSyncTests.balancesResponse(),
            metadata: [SolanaTokenMetadata] = [],
            metadataError: Error? = nil
        ) {
            self.response = response
            self.metadata = metadata
            self.metadataError = metadataError
        }

        func serviceInfo(baseURL: String?) async throws -> SolanaIndexerServiceInfo {
            throw TestError.unexpectedEndpoint
        }

        func verifyServiceInfo(baseURL: String?, expectedChainId: String) async throws -> SolanaIndexerServiceInfo {
            verifiedBaseURLs.append(baseURL ?? "")
            verifiedExpectedChainIds.append(expectedChainId)
            return SolanaIndexerServiceInfo(
                schemaVersion: 1,
                serviceId: "si.soramitsu.io",
                serviceName: "Solswap Indexer",
                ecosystem: "solana",
                chainId: expectedChainId,
                network: expectedChainId.replacingOccurrences(of: "solana:", with: ""),
                publicBaseUrl: "https://si.soramitsu.io",
                readOnly: true,
                capabilities: [],
                endpoints: [:]
            )
        }

        func balances(wallet: String, baseURL: String?) async throws -> SolanaWalletBalancesResponse {
            XCTAssertEqual(wallet, SolanaBalanceSyncTests.wallet)
            XCTAssertEqual(baseURL, UniversalWalletRegistry.solanaIndexerBaseURL.absoluteString)
            return response
        }

        func assets(wallet: String, baseURL: String?) async throws -> SolanaWalletAssetsResponse {
            throw TestError.unexpectedEndpoint
        }

        func state(wallet: String, baseURL: String?) async throws -> SolanaWalletStateResponse {
            throw TestError.unexpectedEndpoint
        }

        func transactions(
            wallet: String,
            baseURL: String?,
            before: String?,
            limit: Int
        ) async throws -> SolanaWalletTransactionsResponse {
            throw TestError.unexpectedEndpoint
        }

        func tokenMetadata(mint: String, baseURL: String?) async throws -> SolanaTokenMetadata {
            throw TestError.unexpectedEndpoint
        }

        func tokenMetadataBatch(mints: [String], baseURL: String?) async throws -> SolanaTokenMetadataBatchResponse {
            if let metadataError {
                throw metadataError
            }
            metadataBatchCalls.append(mints)
            return SolanaTokenMetadataBatchResponse(
                total: metadata.count,
                syncedAt: 1,
                tokens: metadata.filter { mints.contains($0.mint) }
            )
        }
    }

    private enum TestError: Error {
        case metadataUnavailable
        case unexpectedEndpoint
    }

    private static let wallet = "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk"
    private static let splMint = "So11111111111111111111111111111111111111112"
    private static let token2022Mint = "5Pobwp6d9ihN9Nz38f87gVCEBFMgipFiSM2VtUhVit6w"
    private static let tokenAccount = "9xQeWvG816bUx9EPfQ4vF5xXw4wa9VFeTuzA7h4sFnH"
    private static let token2022Account = "7YttLkHDoYJk5HWB7wZWTsxjZCmMCbU6Uf17dYxcqYND"

    private static func balancesResponse(
        wallet: String = wallet,
        lamports: String = "0",
        uiAmountString: String = "0",
        tokens: [SolanaTokenBalance] = []
    ) -> SolanaWalletBalancesResponse {
        SolanaWalletBalancesResponse(
            wallet: wallet,
            native: SolanaNativeBalance(
                type: "native",
                mint: "SOL",
                lamports: lamports,
                decimals: 9,
                uiAmountString: uiAmountString
            ),
            tokens: tokens,
            total: tokens.count + 1,
            syncedAt: 1_710_000_000_000
        )
    }

    private static func tokenBalance(
        mint: String,
        accountAddress: String,
        amount: String,
        uiAmountString: String,
        decimals: Int,
        program: String
    ) -> SolanaTokenBalance {
        SolanaTokenBalance(
            type: "token",
            accountAddress: accountAddress,
            mint: mint,
            owner: wallet,
            program: program,
            programId: program == "token-2022"
                ? "TokenzQdY11111111111111111111111111111111111"
                : "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA",
            amount: amount,
            decimals: decimals,
            uiAmountString: uiAmountString,
            state: "initialized",
            isNative: false,
            delegatedAmount: nil,
            rentExemptReserve: nil
        )
    }

    private static func tokenMetadata(
        mint: String,
        symbol: String,
        name: String,
        program: String
    ) -> SolanaTokenMetadata {
        SolanaTokenMetadata(
            mint: mint,
            exists: true,
            program: program,
            programId: nil,
            extensions: nil,
            transferFeeConfig: nil,
            transferHook: nil,
            decimals: 6,
            supply: "100000000",
            uiSupplyString: "100",
            mintAuthority: nil,
            freezeAuthority: nil,
            isInitialized: true,
            name: name,
            symbol: symbol,
            uri: nil,
            syncedAt: 1
        )
    }
}

private extension SolanaTokenBalance {
    func copy(owner: String) -> SolanaTokenBalance {
        SolanaTokenBalance(
            type: type,
            accountAddress: accountAddress,
            mint: mint,
            owner: owner,
            program: program,
            programId: programId,
            amount: amount,
            decimals: decimals,
            uiAmountString: uiAmountString,
            state: state,
            isNative: isNative,
            delegatedAmount: delegatedAmount,
            rentExemptReserve: rentExemptReserve
        )
    }
}

/// IOSUX-4: Solana mainnet balances are read from JSON-RPC, not from the SORA indexer (which
/// serves Solana testnet).
final class SolanaRpcBalanceSyncTests: XCTestCase {
    func testReadsSolAndBothTokenProgramsFromTheNode() async throws {
        let rpc = ScriptedSolanaRpc()
        rpc.accounts[Self.wallet] = SolanaAccountInfo(owner: "11111111111111111111111111111111", lamports: 2_500_000_000, executable: false)
        rpc.tokenAccounts = [
            SolanaTransferTransactionBuilder.splTokenProgramAddress: [
                Self.tokenAccount(address: Self.splAccount, mint: Self.usdcMint, amount: "12500000", decimals: 6, program: .splToken),
                // Wrapped SOL is the wallet's own SOL in a token account: not a second balance.
                Self.tokenAccount(address: Self.wrappedSolAccount, mint: "So11111111111111111111111111111111111111112", amount: "1", decimals: 9, program: .splToken, isNative: true),
                // Reported for this owner but held by someone else: not this wallet's balance.
                Self.tokenAccount(address: Self.foreignAccount, mint: Self.usdcMint, amount: "99", decimals: 6, program: .splToken, owner: Self.otherWallet)
            ],
            SolanaTransferTransactionBuilder.token2022ProgramAddress: [
                Self.tokenAccount(address: Self.token2022Account, mint: Self.token2022Mint, amount: "7", decimals: 2, program: .token2022)
            ]
        ]
        let now = Date(timeIntervalSince1970: 1_760_000_000)

        let result = try await SolanaRpcBalanceSync(rpcClient: rpc, now: { now }).balances(
            wallet: Self.wallet,
            network: UniversalWalletRegistry.solanaMainnet
        )

        XCTAssertEqual(rpc.methods, ["getBalance", "getTokenAccountsByOwner(Token)", "getTokenAccountsByOwner(Token)"])
        XCTAssertEqual(result.wallet, Self.wallet)
        XCTAssertEqual(result.chainId, "solana:mainnet")
        XCTAssertEqual(result.nativeBalance.amount, "2500000000")
        XCTAssertEqual(result.nativeBalance.decimals, 9)
        XCTAssertTrue(result.nativeBalance.isNative)
        XCTAssertEqual(result.syncedAtMillis, 1_760_000_000_000)
        XCTAssertEqual(result.tokenBalances.map(\.tokenAccountId), [Self.splAccount, Self.token2022Account])
        XCTAssertEqual(result.tokenBalances.map(\.tokenProgram), ["spl-token", "token-2022"])
        XCTAssertEqual(result.tokenBalances.map(\.contractAddress), [Self.usdcMint, Self.token2022Mint])
        XCTAssertEqual(result.tokenBalances.first?.amount, "12500000")
        XCTAssertEqual(result.tokenBalances.first?.symbol, "EPjF...Dt1v", "Unknown mints are named by their address")
        XCTAssertEqual(result.balances.count, 3)
    }

    func testNodeFailurePropagatesSoTheLastKnownBalanceIsKept() async {
        let rpc = ScriptedSolanaRpc()
        rpc.readError = SolanaRpcClientError.httpStatusCode(429)

        do {
            _ = try await SolanaRpcBalanceSync(rpcClient: rpc).balances(wallet: Self.wallet, network: UniversalWalletRegistry.solanaMainnet)
            XCTFail("A failed read must not become a zero balance")
        } catch {
            XCTAssertEqual(error as? SolanaRpcClientError, .httpStatusCode(429))
        }
    }

    func testPortfolioRead_whenOneTokenProgramCannotBeRead_thenSolLoadsAndNoPartialTokenListIsReported() async throws {
        let rpc = ScriptedSolanaRpc()
        rpc.accounts[Self.wallet] = SolanaAccountInfo(owner: "11111111111111111111111111111111", lamports: 2_500_000_000, executable: false)
        rpc.tokenAccounts = [
            SolanaTransferTransactionBuilder.splTokenProgramAddress: [
                Self.tokenAccount(address: Self.splAccount, mint: Self.usdcMint, amount: "12500000", decimals: 6, program: .splToken)
            ]
        ]
        rpc.tokenReadError = SolanaRpcClientError.httpStatusCode(403)
        rpc.tokenReadErrorProgramId = SolanaTransferTransactionBuilder.token2022ProgramAddress

        let result = try await SolanaRpcBalanceSync(rpcClient: rpc).portfolioBalances(
            wallet: Self.wallet,
            network: UniversalWalletRegistry.solanaMainnet,
            rpcURL: nil
        )

        XCTAssertEqual(result.nativeBalance.amount, "2500000000")
        XCTAssertTrue(result.tokenBalancesUnavailable)
        // The SPL list alone would read as "no Token-2022 tokens": nothing partial is reported.
        XCTAssertTrue(result.tokenBalances.isEmpty)
        XCTAssertEqual(result.balances.map(\.assetId), ["SOL"])

        // When every read succeeds the result is complete.
        rpc.tokenReadError = nil
        let complete = try await SolanaRpcBalanceSync(rpcClient: rpc).portfolioBalances(
            wallet: Self.wallet,
            network: UniversalWalletRegistry.solanaMainnet,
            rpcURL: nil
        )
        XCTAssertFalse(complete.tokenBalancesUnavailable)
        XCTAssertEqual(complete.tokenBalances.map(\.tokenAccountId), [Self.splAccount])
    }

    func testPortfolioRead_whenSolCannotBeRead_thenItFailsSoTheLastKnownBalanceIsKept() async {
        let rpc = ScriptedSolanaRpc()
        rpc.readError = SolanaRpcClientError.httpStatusCode(429)

        do {
            _ = try await SolanaRpcBalanceSync(rpcClient: rpc).portfolioBalances(
                wallet: Self.wallet,
                network: UniversalWalletRegistry.solanaMainnet,
                rpcURL: nil
            )
            XCTFail("A failed SOL read must not become a zero balance")
        } catch {
            XCTAssertEqual(error as? SolanaRpcClientError, .httpStatusCode(429))
        }
    }

    func testRejectsAWalletThatIsNotACanonicalAddress() async {
        let rpc = ScriptedSolanaRpc()

        for wallet in ["not-base58", " \(Self.wallet)"] {
            do {
                _ = try await SolanaRpcBalanceSync(rpcClient: rpc).balances(wallet: wallet, network: UniversalWalletRegistry.solanaMainnet)
                XCTFail("Expected \(wallet.debugDescription) to be refused")
            } catch {}
        }
        XCTAssertTrue(rpc.methods.isEmpty)
    }

    func testAppReadsMainnetBalancesThroughTheFailoverNodes() throws {
        let sync = try XCTUnwrap(SolanaRpcBalanceSync.mainnet)
        XCTAssertNotNil(sync as SolanaBalanceSyncing)
        XCTAssertEqual(SolanaFailoverRpcClient.mainnet?.endpoints, [
            "https://api.mainnet-beta.solana.com",
            "https://solana-rpc.publicnode.com",
            "https://public.rpc.solanavibestation.com"
        ])
    }

    private static func tokenAccount(
        address: String,
        mint: String,
        amount: String,
        decimals: Int,
        program: SolanaTokenProgram,
        owner: String = wallet,
        isNative: Bool = false
    ) -> SolanaParsedTokenAccount {
        SolanaParsedTokenAccount(
            address: address,
            mint: mint,
            owner: owner,
            amount: amount,
            decimals: decimals,
            uiAmountString: nil,
            programId: program.programAddress,
            program: program == .splToken ? "spl-token" : "spl-token-2022",
            state: "initialized",
            isNative: isNative
        )
    }

    private static let wallet = "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk"
    private static let otherWallet = "9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM"
    private static let usdcMint = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"
    private static let token2022Mint = "2b1kV6DkPAnxd5ixfnxCpjxmKwqjjaYmCZfHsFu24GXo"
    private static let splAccount = "5N3f1tj9v1vc5TUZ8S7mCAnVmjVKrfnzXWhxLaxyZAgt"
    private static let wrappedSolAccount = "3Mc6vR8ZuxJ7S6oRAQJ8rvxk8nBBWqfnXWDE6QvzgSkd"
    private static let foreignAccount = "4Desus4e9nuCQLgzwnHf87NijwBTi4xJmPg7EzBNkeVE"
    private static let token2022Account = "7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2"
}
