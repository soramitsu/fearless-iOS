import XCTest
@testable import fearless
import BigInt
import SSFModels
import SSFUtils

final class SolanaSendServiceTests: XCTestCase {
    func testPreparesSignedTransferWithFeeAndSimulationWithoutBroadcasting() async throws {
        let rpc = FakeSolanaRpcClient()
        let prepared = try await SolanaSendService(rpcClient: rpc).prepare(Self.request(rpcURL: Self.devnetRPC))

        XCTAssertEqual(prepared.feeLamports, 5_000)
        XCTAssertEqual(prepared.unsigned.senderAddress, Self.sender)
        XCTAssertEqual(prepared.unsigned.recipientAddress, Self.recipient)
        XCTAssertEqual(prepared.unsigned.recentBlockhash, Self.blockhash)
        XCTAssertEqual(prepared.signed.signer, Self.sender)
        XCTAssertEqual(rpc.feeMessages, [prepared.unsigned.messageBase64])
        XCTAssertEqual(rpc.simulatedTransactions, [prepared.signed.signedTransactionBase64])
        XCTAssertEqual(prepared.simulation?.value.unitsConsumed, 42)
        XCTAssertNil(rpc.sentTransaction)
        XCTAssertEqual(rpc.urls, Array(repeating: Self.devnetRPC, count: 3))
    }

    func testSendsSignedTransferAndRequiresMatchingBroadcastSignature() async throws {
        let rpc = FakeSolanaRpcClient()
        let sent = try await SolanaSendService(rpcClient: rpc).send(Self.request(rpcURL: Self.devnetRPC))

        XCTAssertEqual(sent.signature, sent.prepared.signed.signatureBase58)
        XCTAssertEqual(rpc.sentTransaction, sent.prepared.signed.signedTransactionBase64)
        XCTAssertEqual(rpc.broadcastOptions?.preflightCommitment, .finalized)
        XCTAssertEqual(rpc.broadcastOptions?.maxRetries, 3)
    }

    func testSolanaTransferServiceEstimatesFeeAndSendsNativeSOL() async throws {
        let chain = Self.solanaChain(historyBaseURL: "https://si.soramitsu.io/")
        let wallet = try Self.walletWithSolanaAccount(chainId: chain.chainId)
        let rpc = FakeSolanaRpcClient()
        let balanceSync = FakeSolanaTransferBalanceSync(nativeLamports: "2000000000")
        let service = try SolanaTransferService(
            wallet: wallet,
            chain: chain,
            rpcClient: rpc,
            balanceSync: balanceSync,
            mnemonicProvider: FakeUniversalWalletMnemonicProvider(mnemonic: Self.mnemonic)
        )
        let transfer = Self.nativeTransfer(chain: chain)

        let fee = try await service.estimateFee(for: transfer)
        let signature = try await service.submit(transfer: transfer)

        XCTAssertEqual(fee, BigUInt(5_000))
        XCTAssertEqual(signature, rpc.sentSignature)
        XCTAssertEqual(rpc.urls, Array(repeating: Self.mainnetRPC, count: 6))
        XCTAssertEqual(balanceSync.invocations, [
            FakeSolanaTransferBalanceSync.Invocation(
                wallet: Self.sender,
                network: UniversalWalletRegistry.solanaMainnet,
                baseURL: "https://si.soramitsu.io/",
                includeTokenMetadata: false
            )
        ])
    }

    func testSolanaTransferServiceUsesDevnetRegistryRPCWhenNoNodeExists() async throws {
        let chain = Self.solanaChain(network: UniversalWalletRegistry.solanaDevnet, nodes: [])
        let wallet = try Self.walletWithSolanaAccount(chainId: chain.chainId)
        let rpc = FakeSolanaRpcClient()
        let service = try SolanaTransferService(
            wallet: wallet,
            chain: chain,
            rpcClient: rpc,
            balanceSync: FakeSolanaTransferBalanceSync(nativeLamports: "2000000000"),
            mnemonicProvider: FakeUniversalWalletMnemonicProvider(mnemonic: Self.mnemonic)
        )

        _ = try await service.estimateFee(for: Self.nativeTransfer(chain: chain))

        XCTAssertEqual(rpc.urls, Array(repeating: Self.devnetRPC, count: 2))
    }

    func testSolanaTransferServiceEstimatesFeeAndSendsStandardSPLToken() async throws {
        let chain = Self.solanaChain(assets: [Self.solAsset, Self.usdcAsset])
        let wallet = try Self.walletWithSolanaAccount(chainId: chain.chainId)
        let rpc = FakeSolanaRpcClient()
        let balanceSync = FakeSolanaTransferBalanceSync(
            nativeLamports: "2000000000",
            tokenBalances: [Self.tokenIndexedBalance(amount: "5000000")]
        )
        let service = try SolanaTransferService(
            wallet: wallet,
            chain: chain,
            rpcClient: rpc,
            balanceSync: balanceSync,
            mnemonicProvider: FakeUniversalWalletMnemonicProvider(mnemonic: Self.mnemonic)
        )
        let transfer = Transfer(
            chainAsset: ChainAsset(chain: chain, asset: Self.usdcAsset),
            amount: BigUInt(1_250_000),
            receiver: Self.recipient,
            tip: nil,
            appId: nil
        )

        let fee = try await service.estimateFee(for: transfer)
        let signature = try await service.submit(transfer: transfer)
        let destinationTokenAccount = try SolanaTransferTransactionBuilder.deriveAssociatedTokenAccountAddress(
            walletAddress: Self.recipient,
            mintAddress: Self.mint,
            tokenProgram: .splToken
        )

        XCTAssertEqual(fee, BigUInt(5_000))
        XCTAssertEqual(signature, rpc.sentSignature)
        XCTAssertEqual(rpc.accountExistsRequests, [destinationTokenAccount, destinationTokenAccount])
        XCTAssertEqual(rpc.urls, Array(repeating: Self.mainnetRPC, count: 9))
        XCTAssertEqual(balanceSync.invocations, Array(
            repeating: FakeSolanaTransferBalanceSync.Invocation(
                wallet: Self.sender,
                network: UniversalWalletRegistry.solanaMainnet,
                baseURL: nil,
                includeTokenMetadata: false
            ),
            count: 3
        ))
    }

    func testSolanaTransferServiceRejectsToken2022UntilPolicyUIIsSupported() async throws {
        let chain = Self.solanaChain(assets: [Self.solAsset, Self.usdcAsset])
        let wallet = try Self.walletWithSolanaAccount(chainId: chain.chainId)
        let rpc = FakeSolanaRpcClient()
        let service = try SolanaTransferService(
            wallet: wallet,
            chain: chain,
            rpcClient: rpc,
            balanceSync: FakeSolanaTransferBalanceSync(
                nativeLamports: "2000000000",
                tokenBalances: [
                    Self.tokenIndexedBalance(
                        amount: "5000000",
                        tokenProgram: "token-2022"
                    )
                ]
            ),
            mnemonicProvider: FakeUniversalWalletMnemonicProvider(mnemonic: Self.mnemonic)
        )
        let transfer = Transfer(
            chainAsset: ChainAsset(chain: chain, asset: Self.usdcAsset),
            amount: BigUInt(1_250_000),
            receiver: Self.recipient,
            tip: nil,
            appId: nil
        )

        do {
            _ = try await service.estimateFee(for: transfer)
            XCTFail("Expected Token-2022 transfer fee rejection")
        } catch let TransferServiceError.cannotEstimateFee(reason) {
            XCTAssertTrue(reason.contains("SPL Token"))
        } catch {
            XCTFail("Unexpected Token-2022 transfer fee error: \(error)")
        }
        XCTAssertEqual(rpc.calls, 0)
    }

    func testSolanaTransferServiceRejectsMissingMnemonicRootMaterial() async throws {
        let chain = Self.solanaChain()
        let wallet = try Self.walletWithSolanaAccount(chainId: chain.chainId)
        let service = try SolanaTransferService(
            wallet: wallet,
            chain: chain,
            rpcClient: FakeSolanaRpcClient(),
            balanceSync: FakeSolanaTransferBalanceSync(nativeLamports: "2000000000"),
            mnemonicProvider: FakeUniversalWalletMnemonicProvider(mnemonic: nil)
        )

        do {
            _ = try await service.submit(transfer: Self.nativeTransfer(chain: chain))
            XCTFail("Expected missing mnemonic rejection")
        } catch let TransferServiceError.transferFailed(reason) {
            XCTAssertTrue(reason.contains("mnemonic"))
        } catch {
            XCTFail("Unexpected missing mnemonic error: \(error)")
        }
    }

    func testSolanaTransferServiceRejectsMnemonicMismatchBeforeRPCOrIndexerCalls() async throws {
        let chain = Self.solanaChain(historyBaseURL: "https://si.soramitsu.io/")
        let wallet = try Self.walletWithSolanaAccount(chainId: chain.chainId)
        let rpc = FakeSolanaRpcClient()
        let balanceSync = FakeSolanaTransferBalanceSync(nativeLamports: "2000000000")
        let service = try SolanaTransferService(
            wallet: wallet,
            chain: chain,
            rpcClient: rpc,
            balanceSync: balanceSync,
            mnemonicProvider: FakeUniversalWalletMnemonicProvider(mnemonic: Self.otherMnemonic)
        )

        do {
            _ = try await service.submit(transfer: Self.nativeTransfer(chain: chain))
            XCTFail("Expected Solana transfer service to reject mismatched mnemonic material")
        } catch let TransferServiceError.transferFailed(reason) {
            XCTAssertTrue(reason.contains("does not match selected wallet"))
        } catch {
            XCTFail("Unexpected mismatched mnemonic error: \(error)")
        }
        XCTAssertEqual(rpc.calls, 0)
        XCTAssertTrue(balanceSync.invocations.isEmpty)
    }

    func testPreparesSignedTokenTransferWithFeeAndSimulationWithoutBroadcasting() async throws {
        let rpc = FakeSolanaRpcClient()
        let prepared = try await SolanaSendService(rpcClient: rpc).prepareTokenTransfer(Self.tokenRequest(rpcURL: Self.devnetRPC))
        let parsed = try SolanaTransactionSigner.parseSerializedTransaction(prepared.unsigned.transaction)

        XCTAssertEqual(prepared.feeLamports, 5_000)
        XCTAssertEqual(prepared.unsigned.ownerAddress, Self.sender)
        XCTAssertEqual(prepared.unsigned.sourceTokenAccount, Self.sourceTokenAccount)
        XCTAssertEqual(prepared.unsigned.destinationTokenAccount, Self.destinationTokenAccount)
        XCTAssertEqual(prepared.unsigned.mintAddress, Self.mint)
        XCTAssertFalse(prepared.unsigned.createsDestinationAssociatedTokenAccount)
        XCTAssertEqual(parsed.instructionCount, 1)
        XCTAssertEqual(prepared.signed.signer, Self.sender)
        XCTAssertEqual(rpc.feeMessages, [prepared.unsigned.messageBase64])
        XCTAssertEqual(rpc.simulatedTransactions, [prepared.signed.signedTransactionBase64])
        XCTAssertEqual(prepared.simulation?.value.unitsConsumed, 42)
        XCTAssertNil(rpc.sentTransaction)
        XCTAssertEqual(rpc.urls, Array(repeating: Self.devnetRPC, count: 3))
    }

    func testSendsTokenTransferWithAssociatedTokenAccountCreateAndRequiresMatchingSignature() async throws {
        let rpc = FakeSolanaRpcClient()
        let sent = try await SolanaSendService(rpcClient: rpc).sendTokenTransfer(
            Self.tokenRequest(
                destinationTokenAccount: nil,
                destinationWalletAddress: Self.destinationWallet,
                rpcURL: Self.devnetRPC,
                tokenProgram: .token2022,
                extraAccounts: [
                    SolanaTokenTransferExtraAccount(address: Self.extraReadonlyAccount),
                    SolanaTokenTransferExtraAccount(address: Self.extraWritableAccount, isWritable: true)
                ]
            )
        )
        let parsed = try SolanaTransactionSigner.parseSerializedTransaction(sent.prepared.unsigned.transaction)

        XCTAssertEqual(sent.signature, sent.prepared.signed.signatureBase58)
        XCTAssertTrue(sent.prepared.unsigned.createsDestinationAssociatedTokenAccount)
        XCTAssertEqual(sent.prepared.unsigned.destinationWalletAddress, Self.destinationWallet)
        XCTAssertEqual(sent.prepared.unsigned.destinationTokenAccount, Self.destinationWalletToken2022AssociatedTokenAccount)
        XCTAssertEqual(sent.prepared.unsigned.tokenProgram, .token2022)
        XCTAssertEqual(parsed.instructionCount, 2)
        XCTAssertEqual(rpc.accountExistsRequests, [Self.destinationWalletToken2022AssociatedTokenAccount])
        XCTAssertEqual(rpc.sentTransaction, sent.prepared.signed.signedTransactionBase64)
        XCTAssertEqual(rpc.broadcastOptions?.preflightCommitment, .finalized)
        XCTAssertEqual(rpc.broadcastOptions?.maxRetries, 3)
    }

    func testPreparesTokenTransferWithoutAssociatedTokenAccountCreateWhenDestinationAccountExists() async throws {
        let rpc = FakeSolanaRpcClient(existingAccounts: [Self.destinationWalletToken2022AssociatedTokenAccount])
        let prepared = try await SolanaSendService(rpcClient: rpc).prepareTokenTransfer(
            Self.tokenRequest(
                destinationTokenAccount: nil,
                destinationWalletAddress: Self.destinationWallet,
                tokenProgram: .token2022
            )
        )
        let parsed = try SolanaTransactionSigner.parseSerializedTransaction(prepared.unsigned.transaction)

        XCTAssertFalse(prepared.unsigned.createsDestinationAssociatedTokenAccount)
        XCTAssertNil(prepared.unsigned.destinationWalletAddress)
        XCTAssertEqual(prepared.unsigned.destinationTokenAccount, Self.destinationWalletToken2022AssociatedTokenAccount)
        XCTAssertEqual(parsed.instructionCount, 1)
        XCTAssertEqual(rpc.accountExistsRequests, [Self.destinationWalletToken2022AssociatedTokenAccount])
    }

    func testRejectsInvalidRequestParametersBeforeRPCCalls() async {
        let rpc = FakeSolanaRpcClient()
        await assertTransferError(.invalidLamports) {
            _ = try await SolanaSendService(rpcClient: rpc).prepare(Self.request(lamports: 0))
        }
        await assertTransferError(.invalidRecipient) {
            _ = try await SolanaSendService(rpcClient: rpc).prepare(Self.request(recipientAddress: "not-base58"))
        }
        XCTAssertEqual(rpc.calls, 0)
    }

    func testRejectsInvalidTokenRequestParametersAndAccountDerivationFailures() async {
        let rpc = FakeSolanaRpcClient()

        await assertSendError(.invalidAccount) {
            _ = try await SolanaSendService(rpcClient: rpc).prepareTokenTransfer(
                Self.tokenRequest(derivationPath: "m/44'/501'/0/0'")
            )
        }
        XCTAssertEqual(rpc.calls, 0)

        await assertTransferError(.invalidTokenAmount) {
            _ = try await SolanaSendService(rpcClient: rpc).prepareTokenTransfer(Self.tokenRequest(rawAmount: 0))
        }
        await assertTransferError(.invalidWallet) {
            _ = try await SolanaSendService(rpcClient: rpc).prepareTokenTransfer(
                Self.tokenRequest(destinationWalletAddress: "not-base58")
            )
        }
        await assertTransferError(.invalidAssociatedTokenAccount) {
            _ = try await SolanaSendService(rpcClient: rpc).prepareTokenTransfer(
                Self.tokenRequest(
                    destinationTokenAccount: Self.destinationTokenAccount,
                    destinationWalletAddress: Self.destinationWallet,
                    tokenProgram: .token2022
                )
            )
        }
        XCTAssertTrue(rpc.accountExistsRequests.isEmpty)
    }

    func testRejectsUnsafeToken2022ExtensionMetadataBeforeRPCCalls() async {
        await assertSendError(.tokenMetadataMismatch) {
            _ = try await SolanaSendService(rpcClient: FakeSolanaRpcClient()).prepareTokenTransfer(
                Self.tokenRequest(
                    tokenProgram: .token2022,
                    tokenMetadata: Self.tokenMetadata(mint: Self.destinationTokenAccount)
                )
            )
        }
        await assertSendError(.unsupportedToken2022Extension) {
            _ = try await SolanaSendService(rpcClient: FakeSolanaRpcClient()).prepareTokenTransfer(
                Self.tokenRequest(
                    tokenProgram: .token2022,
                    tokenMetadata: Self.tokenMetadata(extensions: ["nonTransferable"])
                )
            )
        }
        await assertSendError(.token2022TransferFeeNotAcknowledged) {
            _ = try await SolanaSendService(rpcClient: FakeSolanaRpcClient()).prepareTokenTransfer(
                Self.tokenRequest(
                    tokenProgram: .token2022,
                    tokenMetadata: Self.tokenMetadata(
                        extensions: ["transferFeeConfig"],
                        transferFeeConfig: SolanaTokenTransferFeeConfig(
                            transferFeeConfigAuthority: nil,
                            withdrawWithheldAuthority: nil,
                            withheldAmount: "0",
                            olderTransferFee: nil,
                            newerTransferFee: nil
                        )
                    )
                )
            )
        }
        let hookRpc = FakeSolanaRpcClient()
        await assertSendError(.token2022TransferHookAccountsMissing) {
            _ = try await SolanaSendService(rpcClient: hookRpc).prepareTokenTransfer(
                Self.tokenRequest(
                    tokenProgram: .token2022,
                    tokenMetadata: Self.tokenMetadata(
                        extensions: ["transferHook"],
                        transferHook: SolanaTokenTransferHook(
                            authority: nil,
                            programId: Self.extraReadonlyAccount,
                            extraAccountMetasAddress: nil
                        )
                    )
                )
            )
        }

        XCTAssertEqual(hookRpc.calls, 0)
    }

    func testAllowsToken2022TransferFeeAfterAcknowledgementAndHookWithExtraAccounts() async throws {
        let feePrepared = try await SolanaSendService(rpcClient: FakeSolanaRpcClient()).prepareTokenTransfer(
            Self.tokenRequest(
                tokenProgram: .token2022,
                tokenMetadata: Self.tokenMetadata(
                    extensions: ["transferFeeConfig"],
                    transferFeeConfig: SolanaTokenTransferFeeConfig(
                        transferFeeConfigAuthority: nil,
                        withdrawWithheldAuthority: nil,
                        withheldAmount: "0",
                        olderTransferFee: nil,
                        newerTransferFee: nil
                    )
                ),
                acknowledgeToken2022TransferFee: true
            )
        )
        let hookPrepared = try await SolanaSendService(rpcClient: FakeSolanaRpcClient()).prepareTokenTransfer(
            Self.tokenRequest(
                tokenProgram: .token2022,
                extraAccounts: [SolanaTokenTransferExtraAccount(address: Self.extraReadonlyAccount)],
                tokenMetadata: Self.tokenMetadata(
                    extensions: ["transferHook"],
                    transferHook: SolanaTokenTransferHook(
                        authority: nil,
                        programId: Self.extraReadonlyAccount,
                        extraAccountMetasAddress: nil
                    )
                )
            )
        )

        XCTAssertEqual(feePrepared.unsigned.tokenProgram, .token2022)
        XCTAssertEqual(hookPrepared.unsigned.tokenProgram, .token2022)
        XCTAssertEqual(hookPrepared.unsigned.extraAccounts, [SolanaTokenTransferExtraAccount(address: Self.extraReadonlyAccount)])
    }

    func testRejectsNativeSendWhenSOLBalanceCannotCoverAmountPlusFee() async {
        let rpc = FakeSolanaRpcClient()
        let balances = FakeSolanaSendBalanceProvider(nativeLamports: "1004999")

        await assertSendError(.insufficientSolBalance) {
            _ = try await SolanaSendService(rpcClient: rpc, balanceProvider: balances).prepare(Self.request())
        }

        XCTAssertEqual(balances.wallets, [Self.sender])
        XCTAssertTrue(rpc.simulatedTransactions.isEmpty)
        XCTAssertNil(rpc.sentTransaction)
    }

    func testRejectsTokenSendWhenSourceTokenBalanceIsMissingOrTooSmall() async {
        let rpc = FakeSolanaRpcClient()
        let missingTokenBalances = FakeSolanaSendBalanceProvider(nativeLamports: "9999999999")

        await assertSendError(.insufficientTokenBalance) {
            _ = try await SolanaSendService(
                rpcClient: rpc,
                balanceProvider: missingTokenBalances
            ).prepareTokenTransfer(Self.tokenRequest())
        }

        let tooSmallTokenBalances = FakeSolanaSendBalanceProvider(
            nativeLamports: "9999999999",
            tokenBalances: [Self.tokenIndexedBalance(amount: "999999")]
        )
        await assertSendError(.insufficientTokenBalance) {
            _ = try await SolanaSendService(
                rpcClient: FakeSolanaRpcClient(),
                balanceProvider: tooSmallTokenBalances
            ).prepareTokenTransfer(Self.tokenRequest())
        }
    }

    func testIncludesAssociatedTokenAccountRentInTokenSendSOLBalanceCheck() async {
        let rent: Int64 = 2_039_280
        let rpc = FakeSolanaRpcClient(rentLamports: rent)
        let balances = FakeSolanaSendBalanceProvider(
            nativeLamports: String(5_000 + rent - 1),
            tokenBalances: [Self.tokenIndexedBalance(amount: "1000000")]
        )

        await assertSendError(.insufficientSolBalance) {
            _ = try await SolanaSendService(rpcClient: rpc, balanceProvider: balances).prepareTokenTransfer(
                Self.tokenRequest(destinationTokenAccount: nil, destinationWalletAddress: Self.destinationWallet)
            )
        }

        XCTAssertEqual(rpc.rentDataLengthRequests, [165])
        XCTAssertEqual(rpc.accountExistsRequests, [Self.destinationWalletAssociatedTokenAccount])
        XCTAssertTrue(rpc.simulatedTransactions.isEmpty)
    }

    func testSkipsAssociatedTokenAccountRentWhenDestinationAccountExists() async throws {
        let rpc = FakeSolanaRpcClient(existingAccounts: [Self.destinationWalletAssociatedTokenAccount])
        let balances = FakeSolanaSendBalanceProvider(
            nativeLamports: "5000",
            tokenBalances: [Self.tokenIndexedBalance(amount: "1000000")]
        )
        let prepared = try await SolanaSendService(rpcClient: rpc, balanceProvider: balances).prepareTokenTransfer(
            Self.tokenRequest(destinationTokenAccount: nil, destinationWalletAddress: Self.destinationWallet)
        )

        XCTAssertFalse(prepared.unsigned.createsDestinationAssociatedTokenAccount)
        XCTAssertTrue(rpc.rentDataLengthRequests.isEmpty)
        XCTAssertEqual(rpc.accountExistsRequests, [Self.destinationWalletAssociatedTokenAccount])
    }

    func testRejectsUnavailableFeesSimulationFailuresAndBroadcastMismatches() async {
        await assertSendError(.feeUnavailable) {
            _ = try await SolanaSendService(rpcClient: FakeSolanaRpcClient(fee: nil)).prepare(Self.request())
        }
        await assertSendError(.simulationFailed) {
            _ = try await SolanaSendService(
                rpcClient: FakeSolanaRpcClient(simulationError: #"{"InstructionError":[0,"Custom"]}"#)
            ).prepare(Self.request())
        }
        await assertSendError(.broadcastSignatureMismatch) {
            _ = try await SolanaSendService(
                rpcClient: FakeSolanaRpcClient(
                    signatureOverride: "5NfHnqDyzT9qyfxZDq2sSskAMGuFZ3VRqW4EQxghKqrKYdKq6cZNW1J34w7qE6nGx1eDQe5s2eKxB2ZtE1xU9qgN"
                )
            ).send(Self.request())
        }
    }

    private final class FakeSolanaRpcClient: SolanaRpcClientProtocol {
        private let fee: Int64?
        private let simulationError: String?
        private let signatureOverride: String?
        private let rentLamports: Int64
        private let existingAccounts: Set<String>
        private(set) var feeMessages: [String] = []
        private(set) var simulatedTransactions: [String] = []
        private(set) var rentDataLengthRequests: [Int] = []
        private(set) var accountExistsRequests: [String] = []
        private(set) var urls: [String?] = []
        private(set) var broadcastOptions: SolanaBroadcastOptions?
        private(set) var calls = 0
        private(set) var sentTransaction: String?
        private(set) var sentSignature: String?

        init(
            fee: Int64? = 5_000,
            simulationError: String? = nil,
            signatureOverride: String? = nil,
            rentLamports: Int64 = 2_039_280,
            existingAccounts: Set<String> = []
        ) {
            self.fee = fee
            self.simulationError = simulationError
            self.signatureOverride = signatureOverride
            self.rentLamports = rentLamports
            self.existingAccounts = existingAccounts
        }

        func latestBlockhash(
            commitment: SolanaRpcCommitment,
            rpcURL: String?
        ) async throws -> SolanaLatestBlockhashResponse {
            calls += 1
            urls.append(rpcURL)
            return SolanaLatestBlockhashResponse(
                context: SolanaRpcContext(apiVersion: nil, slot: 1),
                value: SolanaLatestBlockhash(blockhash: SolanaSendServiceTests.blockhash, lastValidBlockHeight: 99)
            )
        }

        func feeForMessage(
            _ messageBase64: String,
            commitment: SolanaRpcCommitment,
            rpcURL: String?
        ) async throws -> SolanaFeeForMessageResponse {
            calls += 1
            urls.append(rpcURL)
            feeMessages.append(messageBase64)
            return SolanaFeeForMessageResponse(
                context: SolanaRpcContext(apiVersion: nil, slot: 2),
                value: fee
            )
        }

        func minimumBalanceForRentExemption(
            dataLength: Int,
            commitment: SolanaRpcCommitment,
            rpcURL: String?
        ) async throws -> Int64 {
            calls += 1
            urls.append(rpcURL)
            rentDataLengthRequests.append(dataLength)
            return rentLamports
        }

        func accountExists(
            address: String,
            commitment: SolanaRpcCommitment,
            rpcURL: String?
        ) async throws -> Bool {
            calls += 1
            urls.append(rpcURL)
            accountExistsRequests.append(address)
            return existingAccounts.contains(address)
        }

        func simulateTransaction(
            _ transactionBase64: String,
            options: SolanaSimulationOptions,
            rpcURL: String?
        ) async throws -> SolanaSimulationResponse {
            calls += 1
            urls.append(rpcURL)
            simulatedTransactions.append(transactionBase64)
            return SolanaSimulationResponse(
                context: SolanaRpcContext(apiVersion: nil, slot: 3),
                value: SolanaSimulationValue(
                    errorJSON: simulationError,
                    logs: ["Program log: ok"],
                    replacementBlockhash: nil,
                    unitsConsumed: 42
                )
            )
        }

        func sendRawTransaction(
            _ transactionBase64: String,
            options: SolanaBroadcastOptions,
            rpcURL: String?
        ) async throws -> String {
            calls += 1
            urls.append(rpcURL)
            broadcastOptions = options
            sentTransaction = transactionBase64

            if let signatureOverride {
                sentSignature = signatureOverride
                return signatureOverride
            }

            let signature = try Self.firstSignature(transactionBase64)
            sentSignature = signature
            return signature
        }

        private static func firstSignature(_ transactionBase64: String) throws -> String {
            let transaction = try XCTUnwrap(Data(base64Encoded: transactionBase64))
            let parsed = try SolanaTransactionSigner.parseSerializedTransaction(transaction)
            return base58Encode(Array(transaction.subdata(in: parsed.signaturesOffset ..< parsed.signaturesOffset + 64)))
        }

        private static func base58Encode(_ bytes: [UInt8]) -> String {
            let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
            var digits: [Int] = []

            for byte in bytes {
                var carry = Int(byte)

                for index in digits.indices {
                    let value = digits[index] * 256 + carry
                    digits[index] = value % alphabet.count
                    carry = value / alphabet.count
                }

                while carry > 0 {
                    digits.append(carry % alphabet.count)
                    carry /= alphabet.count
                }
            }

            var result = String(repeating: String(alphabet[0]), count: bytes.prefix { $0 == 0 }.count)
            for digit in digits.reversed() {
                result.append(alphabet[digit])
            }

            return result
        }
    }

    private final class FakeSolanaSendBalanceProvider: SolanaSendBalanceProvider {
        private let nativeLamports: String
        private let tokenBalances: [UniversalWalletIndexedAssetBalance]
        private(set) var wallets: [String] = []

        init(
            nativeLamports: String,
            tokenBalances: [UniversalWalletIndexedAssetBalance] = []
        ) {
            self.nativeLamports = nativeLamports
            self.tokenBalances = tokenBalances
        }

        func balances(wallet: String) async throws -> SolanaBalanceSyncResult {
            wallets.append(wallet)
            let native = SolanaSendServiceTests.nativeIndexedBalance(amount: nativeLamports)
            return SolanaBalanceSyncResult(
                wallet: wallet,
                networkId: "solana-mainnet",
                chainId: "solana:mainnet",
                syncedAtMillis: 1,
                nativeBalance: native,
                tokenBalances: tokenBalances,
                balances: [native] + tokenBalances
            )
        }
    }

    private struct FakeUniversalWalletMnemonicProvider: UniversalWalletMnemonicProviding {
        let mnemonic: String?

        func mnemonic(for _: MetaAccountModel, chain _: ChainModel) throws -> String? {
            mnemonic
        }
    }

    private final class FakeSolanaTransferBalanceSync: SolanaBalanceSyncing {
        struct Invocation: Equatable {
            let wallet: String
            let network: UniversalWalletRegistry.SolanaNetwork
            let baseURL: String?
            let includeTokenMetadata: Bool
        }

        private let nativeLamports: String
        private let tokenBalances: [UniversalWalletIndexedAssetBalance]
        private(set) var invocations: [Invocation] = []

        init(
            nativeLamports: String,
            tokenBalances: [UniversalWalletIndexedAssetBalance] = []
        ) {
            self.nativeLamports = nativeLamports
            self.tokenBalances = tokenBalances
        }

        func balances(
            wallet: String,
            network: UniversalWalletRegistry.SolanaNetwork,
            baseURL: String?,
            includeTokenMetadata: Bool
        ) async throws -> SolanaBalanceSyncResult {
            invocations.append(
                Invocation(
                    wallet: wallet,
                    network: network,
                    baseURL: baseURL,
                    includeTokenMetadata: includeTokenMetadata
                )
            )
            let native = UniversalWalletIndexedAssetBalance(
                accountId: network.id,
                ecosystem: .solana,
                chainId: network.chainId,
                assetId: network.nativeAsset.id,
                amount: nativeLamports,
                decimals: network.nativeAsset.decimals,
                isNative: true,
                symbol: network.nativeAsset.symbol,
                name: network.name,
                uiAmountString: "2",
                syncedAtMillis: 1
            )

            return SolanaBalanceSyncResult(
                wallet: wallet,
                networkId: network.id,
                chainId: network.chainId,
                syncedAtMillis: 1,
                nativeBalance: native,
                tokenBalances: tokenBalances,
                balances: [native] + tokenBalances
            )
        }
    }

    private func assertTransferError(
        _ expected: SolanaTransferTransactionError,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () async throws -> Void
    ) async {
        do {
            try await block()
            XCTFail("Expected Solana transfer error", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? SolanaTransferTransactionError, expected, file: file, line: line)
        }
    }

    private func assertSendError(
        _ expected: SolanaSendServiceError,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () async throws -> Void
    ) async {
        do {
            try await block()
            XCTFail("Expected Solana send error", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? SolanaSendServiceError, expected, file: file, line: line)
        }
    }

    private static func request(
        mnemonic: String = SolanaSendServiceTests.mnemonic,
        recipientAddress: String = SolanaSendServiceTests.recipient,
        lamports: Int64 = 1_000_000,
        rpcURL: String? = nil
    ) -> SolanaSendRequest {
        SolanaSendRequest(
            mnemonic: mnemonic,
            recipientAddress: recipientAddress,
            lamports: lamports,
            commitment: .finalized,
            rpcURL: rpcURL,
            broadcastOptions: SolanaBroadcastOptions(maxRetries: 3, preflightCommitment: .finalized)
        )
    }

    private static func tokenRequest(
        mnemonic: String = SolanaSendServiceTests.mnemonic,
        sourceTokenAccount: String = SolanaSendServiceTests.sourceTokenAccount,
        destinationTokenAccount: String? = SolanaSendServiceTests.destinationTokenAccount,
        destinationWalletAddress: String? = nil,
        mintAddress: String = SolanaSendServiceTests.mint,
        rawAmount: Int64 = 1_000_000,
        decimals: Int = 6,
        derivationPath: String = UniversalWalletDerivationPaths.solanaDefault,
        rpcURL: String? = nil,
        tokenProgram: SolanaTokenProgram = .splToken,
        extraAccounts: [SolanaTokenTransferExtraAccount] = [],
        tokenMetadata: SolanaTokenMetadata? = nil,
        acknowledgeToken2022TransferFee: Bool = false
    ) -> SolanaTokenSendRequest {
        SolanaTokenSendRequest(
            mnemonic: mnemonic,
            sourceTokenAccount: sourceTokenAccount,
            destinationTokenAccount: destinationTokenAccount,
            mintAddress: mintAddress,
            rawAmount: rawAmount,
            decimals: decimals,
            derivationPath: derivationPath,
            commitment: .finalized,
            rpcURL: rpcURL,
            tokenProgram: tokenProgram,
            extraAccounts: extraAccounts,
            tokenMetadata: tokenMetadata,
            acknowledgeToken2022TransferFee: acknowledgeToken2022TransferFee,
            destinationWalletAddress: destinationWalletAddress,
            broadcastOptions: SolanaBroadcastOptions(maxRetries: 3, preflightCommitment: .finalized)
        )
    }

    private static func nativeTransfer(chain: ChainModel) -> Transfer {
        Transfer(
            chainAsset: ChainAsset(chain: chain, asset: solAsset),
            amount: BigUInt(1_000_000),
            receiver: recipient,
            tip: nil,
            appId: nil
        )
    }

    private static func walletWithSolanaAccount(chainId: String) throws -> MetaAccountModel {
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: mnemonic)
        let chainAccount = ChainAccountModel(
            chainId: chainId,
            accountId: account.publicKey,
            publicKey: account.publicKey,
            cryptoType: CryptoType.ed25519.rawValue,
            ethereumBased: false
        )

        return AccountGenerator.generateMetaAccount(with: [chainAccount])
    }

    private static func solanaChain(
        network: UniversalWalletRegistry.SolanaNetwork = UniversalWalletRegistry.solanaMainnet,
        historyBaseURL: String? = nil,
        nodes: [ChainNodeModel]? = nil,
        assets: [AssetModel] = [SolanaSendServiceTests.solAsset]
    ) -> ChainModel {
        let resolvedNodes = nodes ?? [
            ChainNodeModel(
                url: network.rpcURL,
                name: network.name,
                apikey: nil
            )
        ]
        let externalApi = historyBaseURL.map {
            ChainModel.ExternalApiSet(
                staking: nil,
                history: ChainModel.BlockExplorer(
                    type: "subquery",
                    url: URL(string: $0)!
                ),
                explorers: nil
            )
        }

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: network.chainId,
            parentId: nil,
            paraId: nil,
            name: network.name,
            assets: Set(assets),
            xcm: nil,
            nodes: Set(resolvedNodes),
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: network == UniversalWalletRegistry.solanaDevnet ? [.testnet] : nil,
            externalApi: externalApi,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    private static let otherMnemonic = "legal winner thank year wave sausage worth useful legal winner thank yellow"
    private static let sender = try! SolanaKeyDerivation.deriveAccount(mnemonic: mnemonic).address
    private static let sourceTokenAccount = try! deriveAddress(1)
    private static let destinationTokenAccount = try! deriveAddress(2)
    private static let mint = try! deriveAddress(3)
    private static let extraReadonlyAccount = try! deriveAddress(4)
    private static let extraWritableAccount = try! deriveAddress(5)
    private static let destinationWallet = try! deriveAddress(7)
    private static let destinationWalletAssociatedTokenAccount = "BNrmzq2GNxwxHf8dSiaEJdtUiQBg4VGCFi9ovhAK6WrK"
    private static let destinationWalletToken2022AssociatedTokenAccount = "2bFPe5wRzpinUSyFT42imC5DFHtEFugZ6UhgBeWRRxhH"
    private static let recipient = "So11111111111111111111111111111111111111112"
    private static let blockhash = "7GjNiPun3AzEazTZoFEjZgcBMeuaXdpjHq2raZTmTrfs"
    private static let mainnetRPC = "https://api.mainnet-beta.solana.com"
    private static let devnetRPC = "https://api.devnet.solana.com"
    private static let solAsset = AssetModel(
        id: "SOL",
        name: "Solana",
        symbol: "SOL",
        precision: 9,
        isUtility: true,
        isNative: true
    )
    private static let usdcAsset = AssetModel(
        id: mint,
        name: "USD Coin",
        symbol: "USDC",
        precision: 6,
        isUtility: false,
        isNative: false
    )

    private static func deriveAddress(_ index: Int) throws -> String {
        try SolanaKeyDerivation
            .deriveAccount(mnemonic: mnemonic, derivationPath: "m/44'/501'/\(index)'/0'")
            .address
    }

    private static func nativeIndexedBalance(amount: String) -> UniversalWalletIndexedAssetBalance {
        UniversalWalletIndexedAssetBalance(
            accountId: "solana-mainnet",
            ecosystem: .solana,
            chainId: "solana:mainnet",
            assetId: "SOL",
            amount: amount,
            decimals: 9,
            isNative: true,
            symbol: "SOL",
            syncedAtMillis: 1
        )
    }

    private static func tokenIndexedBalance(
        amount: String,
        decimals: Int = 6,
        tokenAccount: String = sourceTokenAccount,
        mint: String = SolanaSendServiceTests.mint,
        tokenProgram: String = "spl-token"
    ) -> UniversalWalletIndexedAssetBalance {
        UniversalWalletIndexedAssetBalance(
            accountId: "solana-mainnet",
            ecosystem: .solana,
            chainId: "solana:mainnet",
            assetId: mint,
            amount: amount,
            decimals: decimals,
            isNative: false,
            tokenAccountId: tokenAccount,
            contractAddress: mint,
            tokenProgram: tokenProgram,
            syncedAtMillis: 1
        )
    }

    private static func tokenMetadata(
        mint: String = SolanaSendServiceTests.mint,
        exists: Bool = true,
        program: String = "token-2022",
        programId: String? = SolanaTransferTransactionBuilder.token2022ProgramAddress,
        extensions: [String] = [],
        transferFeeConfig: SolanaTokenTransferFeeConfig? = nil,
        transferHook: SolanaTokenTransferHook? = nil
    ) -> SolanaTokenMetadata {
        SolanaTokenMetadata(
            mint: mint,
            exists: exists,
            program: program,
            programId: programId,
            extensions: extensions,
            transferFeeConfig: transferFeeConfig,
            transferHook: transferHook,
            decimals: 6,
            supply: "100000000",
            uiSupplyString: "100",
            mintAuthority: nil,
            freezeAuthority: nil,
            isInitialized: true,
            name: nil,
            symbol: nil,
            uri: nil,
            syncedAt: 1
        )
    }
}
