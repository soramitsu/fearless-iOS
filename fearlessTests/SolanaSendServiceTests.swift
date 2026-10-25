import XCTest
import Darwin
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
            mnemonicProvider: FakeUniversalWalletMnemonicProvider(mnemonic: Self.mnemonic),
            pendingStore: Self.isolatedPendingStore()
        )
        let transfer = Self.nativeTransfer(chain: chain)

        let fee = try await service.estimateFee(for: transfer)
        let signature = try await service.submit(transfer: transfer)

        XCTAssertEqual(fee, BigUInt(5_000))
        XCTAssertEqual(signature, rpc.sentSignature)
        XCTAssertEqual(Set(rpc.urls), [Self.mainnetRPC])
        // Quote: recipient check, priority fee, blockhash, fee. Submit: recipient and rent
        // checks, then sign, simulate, send once, and confirm the signature; nothing goes to
        // the SORA indexer named in the chain's history URL.
        XCTAssertEqual(rpc.methods, [
            "getAccountInfo",
            "getRecentPrioritizationFees",
            "getLatestBlockhash",
            "getFeeForMessage",
            "getAccountInfo",
            "getMinimumBalanceForRentExemption",
            "getLatestBlockhash",
            "getFeeForMessage",
            "simulateTransaction",
            "sendTransaction",
            "getSignatureStatuses"
        ])
        XCTAssertEqual(balanceSync.invocations, [
            FakeSolanaTransferBalanceSync.Invocation(
                wallet: Self.sender,
                network: UniversalWalletRegistry.solanaMainnet,
                baseURL: nil,
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
            mnemonicProvider: FakeUniversalWalletMnemonicProvider(mnemonic: Self.mnemonic),
            pendingStore: Self.isolatedPendingStore()
        )

        _ = try await service.estimateFee(for: Self.nativeTransfer(chain: chain))

        XCTAssertEqual(rpc.urls, Array(repeating: Self.devnetRPC, count: 4))
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
            mnemonicProvider: FakeUniversalWalletMnemonicProvider(mnemonic: Self.mnemonic),
            pendingStore: Self.isolatedPendingStore()
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

        // The recipient holds no token account yet: the quote is the network fee plus the rent
        // Solana takes from the sender's SOL to open one, because both leave the wallet.
        XCTAssertEqual(fee, BigUInt(5_000 + 2_039_280))
        XCTAssertEqual(signature, rpc.sentSignature)
        XCTAssertEqual(rpc.accountExistsRequests, Array(repeating: destinationTokenAccount, count: 3))
        XCTAssertEqual(rpc.rentDataLengthRequests, [165, 165])
        XCTAssertEqual(Set(rpc.urls), [Self.mainnetRPC])
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

    /// The confirm screen names the deposit that opens the recipient's token account: the fee
    /// quote reports it on its own, and the fee figure still includes it.
    func testFeeQuoteNamesTheRecipientTokenAccountDepositSeparately() async throws {
        let chain = Self.solanaChain(assets: [Self.solAsset, Self.usdcAsset])
        let wallet = try Self.walletWithSolanaAccount(chainId: chain.chainId)
        let destination = try SolanaTransferTransactionBuilder.deriveAssociatedTokenAccountAddress(
            walletAddress: Self.recipient,
            mintAddress: Self.mint,
            tokenProgram: .splToken
        )
        func service(_ rpc: FakeSolanaRpcClient) throws -> SolanaTransferService {
            try SolanaTransferService(
                wallet: wallet,
                chain: chain,
                rpcClient: rpc,
                balanceSync: FakeSolanaTransferBalanceSync(
                    nativeLamports: "2000000000",
                    tokenBalances: [Self.tokenIndexedBalance(amount: "5000000")]
                ),
                mnemonicProvider: FakeUniversalWalletMnemonicProvider(mnemonic: Self.mnemonic),
                pendingStore: Self.isolatedPendingStore()
            )
        }
        let tokenTransfer = Transfer(
            chainAsset: ChainAsset(chain: chain, asset: Self.usdcAsset),
            amount: BigUInt(1_250_000),
            receiver: Self.recipient,
            tip: nil,
            appId: nil
        )

        let opening = try await service(FakeSolanaRpcClient()).estimateFeeQuote(for: tokenTransfer)
        XCTAssertEqual(opening.fee, BigUInt(5_000 + 2_039_280))
        XCTAssertEqual(opening.accountCreationDeposit, BigUInt(2_039_280))
        let existing = try await service(FakeSolanaRpcClient(existingAccounts: [destination])).estimateFeeQuote(for: tokenTransfer)
        XCTAssertEqual(existing.fee, BigUInt(5_000))
        XCTAssertEqual(existing.accountCreationDeposit, .zero)
        let native = try await service(FakeSolanaRpcClient()).estimateFeeQuote(for: Self.nativeTransfer(chain: chain))
        XCTAssertEqual(native.accountCreationDeposit, .zero)

        // The confirm screen hears both numbers; any other listener hears the total, as before.
        let breakdownHeard = expectation(description: "breakdown")
        let breakdown = RecordingFeeListener(expectation: breakdownHeard)
        let quoting = try service(FakeSolanaRpcClient())
        quoting.subscribeForFee(transfer: tokenTransfer, listener: breakdown)
        let totalHeard = expectation(description: "total")
        let total = RecordingTotalFeeListener(expectation: totalHeard)
        let totalQuoting = try service(FakeSolanaRpcClient())
        totalQuoting.subscribeForFee(transfer: tokenTransfer, listener: total)
        await fulfillment(of: [breakdownHeard, totalHeard], timeout: 5)

        XCTAssertEqual(breakdown.breakdowns.map(\.fee), [BigUInt(5_000 + 2_039_280)])
        XCTAssertEqual(breakdown.breakdowns.map(\.deposit), [BigUInt(2_039_280)])
        XCTAssertTrue(breakdown.totals.isEmpty)
        XCTAssertEqual(total.totals, [BigUInt(5_000 + 2_039_280)])
    }

    private final class RecordingFeeListener: SolanaTransferFeeBreakdownListener {
        private let heard: XCTestExpectation
        private(set) var breakdowns: [(fee: BigUInt, deposit: BigUInt)] = []
        private(set) var totals: [BigUInt] = []

        init(expectation: XCTestExpectation) {
            heard = expectation
        }

        func didReceiveSolanaFee(fee: BigUInt, accountCreationDeposit: BigUInt) {
            breakdowns.append((fee, accountCreationDeposit))
            heard.fulfill()
        }

        func didReceiveFee(fee: BigUInt) {
            totals.append(fee)
            heard.fulfill()
        }

        func didReceiveFeeError(feeError _: Error) {
            heard.fulfill()
        }
    }

    private final class RecordingTotalFeeListener: TransferFeeEstimationListener {
        private let heard: XCTestExpectation
        private(set) var totals: [BigUInt] = []

        init(expectation: XCTestExpectation) {
            heard = expectation
        }

        func didReceiveFee(fee: BigUInt) {
            totals.append(fee)
            heard.fulfill()
        }

        func didReceiveFeeError(feeError _: Error) {
            heard.fulfill()
        }
    }

    /// The balance shown sums every token account of the mint; the send picks one account that
    /// holds the amount. An empty associated token account next to a funded one must not make
    /// every send fail as "not enough tokens".
    func testTokenSendSourceIsAnAccountThatHoldsTheAmount() throws {
        let associated = try SolanaTransferTransactionBuilder.deriveAssociatedTokenAccountAddress(
            walletAddress: Self.sender,
            mintAddress: Self.mint,
            tokenProgram: .splToken
        )
        let pick = { (holdings: [UniversalWalletIndexedAssetBalance], amount: BigUInt) in
            try SolanaTransferService.sourceTokenHolding(
                among: holdings, associatedTokenAccount: associated, rawAmount: amount
            )?.tokenAccountId
        }
        let emptyAssociated = Self.tokenIndexedBalance(amount: "0", tokenAccount: associated)
        let smallAssociated = Self.tokenIndexedBalance(amount: "5", tokenAccount: associated)
        let other = Self.tokenIndexedBalance(amount: "100")

        XCTAssertEqual(try pick([emptyAssociated, other], 100), Self.sourceTokenAccount)
        XCTAssertEqual(try pick([smallAssociated, other], 6), Self.sourceTokenAccount)
        XCTAssertEqual(try pick([smallAssociated, other], 5), associated, "the associated account first when it holds the amount")
        XCTAssertEqual(try pick([other], 101), Self.sourceTokenAccount, "too little in total is the balance check's to report")
        XCTAssertThrowsError(try pick([smallAssociated, other], 104)) {
            XCTAssertEqual($0 as? SolanaTransferRefusal, .tokenBalanceSplit)
        }
    }

    func testSolanaTransferServiceSendsFromAFundedSecondaryTokenAccountWhenTheAssociatedOneIsEmpty() async throws {
        let chain = Self.solanaChain(assets: [Self.solAsset, Self.usdcAsset])
        let wallet = try Self.walletWithSolanaAccount(chainId: chain.chainId)
        let associated = try SolanaTransferTransactionBuilder.deriveAssociatedTokenAccountAddress(
            walletAddress: Self.sender,
            mintAddress: Self.mint,
            tokenProgram: .splToken
        )
        let transfer = Transfer(
            chainAsset: ChainAsset(chain: chain, asset: Self.usdcAsset),
            amount: BigUInt(1_250_000),
            receiver: Self.recipient,
            tip: nil,
            appId: nil
        )
        let service = { (tokenBalances: [UniversalWalletIndexedAssetBalance], rpc: FakeSolanaRpcClient) in
            try SolanaTransferService(
                wallet: wallet,
                chain: chain,
                rpcClient: rpc,
                balanceSync: FakeSolanaTransferBalanceSync(nativeLamports: "2000000000", tokenBalances: tokenBalances),
                mnemonicProvider: FakeUniversalWalletMnemonicProvider(mnemonic: Self.mnemonic),
                pendingStore: Self.isolatedPendingStore()
            )
        }

        let rpc = FakeSolanaRpcClient()
        let signature = try await service(
            [Self.tokenIndexedBalance(amount: "0", tokenAccount: associated), Self.tokenIndexedBalance(amount: "5000000")],
            rpc
        ).submit(transfer: transfer)
        XCTAssertEqual(signature, rpc.sentSignature)

        let splitRpc = FakeSolanaRpcClient()
        do {
            _ = try await service(
                [
                    Self.tokenIndexedBalance(amount: "1000000", tokenAccount: associated),
                    Self.tokenIndexedBalance(amount: "1000000")
                ],
                splitRpc
            ).estimateFee(for: transfer)
            XCTFail("an amount no single token account holds is refused")
        } catch {
            XCTAssertEqual(error as? SolanaTransferRefusal, .tokenBalanceSplit)
        }
        XCTAssertNil(splitRpc.sentSignature)
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
            mnemonicProvider: FakeUniversalWalletMnemonicProvider(mnemonic: Self.mnemonic),
            pendingStore: Self.isolatedPendingStore()
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
        } catch let refusal as SolanaTransferRefusal {
            // The user is told the token stays in the wallet and can still be received.
            XCTAssertEqual(refusal, .unsupportedTokenProgram)
            XCTAssertTrue(refusal.toErrorContent(for: nil).message.contains("Token-2022"))
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
    // Explicit protocol fixture binding; endpoint attestation is tested with actual clients separately.
    var expectedGenesisHash: String? = UniversalWalletRegistry.solanaMainnet.genesisHash
    func bound(toGenesisHash genesisHash: String) throws -> SolanaRpcClientProtocol {
        expectedGenesisHash = genesisHash
        return self
    }
    func verifyCluster(rpcURL _: String?) async throws { try Task.checkCancellation() }

        private let fee: Int64?
        private let simulationError: String?
        private let signatureOverride: String?
        private let rentLamports: Int64
        private let existingAccounts: Set<String>
        private let accountInfos: [String: SolanaAccountInfo]
        private let recentFees: [Int64]
        private(set) var feeMessages: [String] = []
        private(set) var accountInfoRequests: [String] = []
        private(set) var prioritizationFeeRequests: [[String]] = []
        private(set) var simulatedTransactions: [String] = []
        private(set) var rentDataLengthRequests: [Int] = []
        private(set) var accountExistsRequests: [String] = []
        private(set) var urls: [String?] = []
        private(set) var methods: [String] = []
        private(set) var broadcastOptions: SolanaBroadcastOptions?
        private(set) var calls = 0
        private(set) var sentTransaction: String?
        private(set) var sentSignature: String?

        init(
            fee: Int64? = 5_000,
            simulationError: String? = nil,
            signatureOverride: String? = nil,
            rentLamports: Int64 = 2_039_280,
            existingAccounts: Set<String> = [],
            accountInfos: [String: SolanaAccountInfo] = [:],
            recentFees: [Int64] = []
        ) {
            self.fee = fee
            self.simulationError = simulationError
            self.signatureOverride = signatureOverride
            self.rentLamports = rentLamports
            self.existingAccounts = existingAccounts
            self.accountInfos = accountInfos
            self.recentFees = recentFees
        }

        func latestBlockhash(
            commitment: SolanaRpcCommitment,
            rpcURL: String?
        ) async throws -> SolanaLatestBlockhashResponse {
            calls += 1
            urls.append(rpcURL)
            methods.append("getLatestBlockhash")
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
            methods.append("getFeeForMessage")
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
            methods.append("getMinimumBalanceForRentExemption")
            // An empty system account and a token account have different minimums on chain.
            return dataLength == 0 ? Self.emptyAccountRentLamports : rentLamports
        }

        func accountExists(
            address: String,
            commitment: SolanaRpcCommitment,
            rpcURL: String?
        ) async throws -> Bool {
            calls += 1
            urls.append(rpcURL)
            accountExistsRequests.append(address)
            methods.append("getAccountInfo(exists)")
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
            methods.append("simulateTransaction")
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
            methods.append("sendTransaction")
            sentTransaction = transactionBase64

            if let signatureOverride {
                sentSignature = signatureOverride
                return signatureOverride
            }

            let signature = try Self.firstSignature(transactionBase64)
            sentSignature = signature
            return signature
        }

        func accountInfo(
            address: String,
            commitment _: SolanaRpcCommitment,
            rpcURL: String?
        ) async throws -> SolanaAccountInfo? {
            calls += 1
            urls.append(rpcURL)
            accountInfoRequests.append(address)
            methods.append("getAccountInfo")
            return accountInfos[address]
        }

        func balance(address _: String, commitment _: SolanaRpcCommitment, rpcURL: String?) async throws -> Int64 {
            calls += 1
            urls.append(rpcURL)
            return 0
        }

        func tokenAccountsByOwner(
            owner _: String,
            programId _: String,
            commitment _: SolanaRpcCommitment,
            rpcURL: String?
        ) async throws -> [SolanaParsedTokenAccount] {
            calls += 1
            urls.append(rpcURL)
            return []
        }

        /// A transaction this fake accepted is reported confirmed, as a healthy cluster would.
        func signatureStatuses(
            _ signatures: [String],
            searchTransactionHistory _: Bool,
            rpcURL: String?
        ) async throws -> [SolanaSignatureStatus?] {
            calls += 1
            urls.append(rpcURL)
            methods.append("getSignatureStatuses")
            let landed = try sentTransaction.map(Self.firstSignature)
            return signatures.map {
                $0 == landed ? SolanaSignatureStatus(slot: 7, confirmationStatus: .confirmed, errorJSON: nil) : nil
            }
        }

        func blockHeight(commitment _: SolanaRpcCommitment, rpcURL: String?) async throws -> Int64 {
            calls += 1
            urls.append(rpcURL)
            methods.append("getBlockHeight")
            return 50
        }

        func recentPrioritizationFees(accounts: [String], rpcURL: String?) async throws -> [Int64] {
            calls += 1
            urls.append(rpcURL)
            prioritizationFeeRequests.append(accounts)
            methods.append("getRecentPrioritizationFees")
            return recentFees
        }

        static let emptyAccountRentLamports: Int64 = 890_880

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

    /// The real record store over a throwaway defaults suite, so no test shares a record.
    static func isolatedPendingStore() -> SolanaPendingBroadcastStore {
        SolanaPendingBroadcastStore(userDefaults: UserDefaults(suiteName: "solana-send-tests-\(UUID().uuidString)")!)
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

// Append to SolanaSendServiceTests.swift. Public local fixtures only; no URLSession/network.
extension SolanaSendServiceTests {
    func testClusterBoundFeeRejectsWrongClusterAtCustomEndpoint() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.devnet)
        do {
            _ = try await fixture.service.estimateFee(for: Self.nativeTransfer(chain: fixture.chain))
            XCTFail("Mainnet fee must not accept a devnet endpoint response")
        } catch {}
        XCTAssertFalse(fixture.transport.methods.contains("getFeeForMessage"))
        XCTAssertEqual(fixture.keys.reads, 0)
    }

    func testClusterBoundFeeAllowsExpectedMainnetAndDevnetCustomEndpoints() async throws {
        for (network, genesis) in [(UniversalWalletRegistry.solanaMainnet, ClusterTransport.mainnet),
                                  (UniversalWalletRegistry.solanaDevnet, ClusterTransport.devnet)] {
            let fixture = try clusterFixture(network: network, genesis: genesis)
            let fee = try await fixture.service.estimateFee(for: Self.nativeTransfer(chain: fixture.chain))
            XCTAssertEqual(fee, BigUInt(5_000))
            XCTAssertEqual(fixture.keys.reads, 0)
            XCTAssertTrue(fixture.transport.methods.contains("getFeeForMessage"))
            XCTAssertFalse(fixture.transport.methods.contains("sendTransaction"))
            XCTAssertEqual(Set(fixture.transport.urls), [ClusterTransport.custom])
        }
    }

    func testClusterBoundBalanceRejectsWrongCluster() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.devnet)
        do {
            _ = try await SolanaRpcBalanceSync(rpcClient: fixture.client).balances(
                wallet: Self.sender, network: UniversalWalletRegistry.solanaMainnet, rpcURL: ClusterTransport.custom)
            XCTFail("Mainnet balance must not display a devnet endpoint's amount")
        } catch {}
        XCTAssertFalse(fixture.transport.methods.contains("getBalance"))
    }

    func testClusterBoundBalanceAllowsExpectedCustomEndpoint() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let result = try await SolanaRpcBalanceSync(rpcClient: fixture.client).balances(
            wallet: Self.sender, network: UniversalWalletRegistry.solanaMainnet, rpcURL: ClusterTransport.custom)
        XCTAssertEqual(result.nativeBalance.amount, "2000000000")
        XCTAssertEqual(result.chainId, UniversalWalletRegistry.solanaMainnet.chainId)
        XCTAssertEqual(fixture.keys.reads, 0)
    }

    func testClusterBoundSubmitRejectsWrongClusterBeforeMnemonicAccess() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.devnet)
        do {
            _ = try await fixture.service.submit(transfer: Self.nativeTransfer(chain: fixture.chain))
            XCTFail("No fixture mnemonic is available")
        } catch {}
        XCTAssertEqual(fixture.keys.reads, 0, "A rejected cluster must not request stored mnemonic material")
        XCTAssertFalse(fixture.transport.methods.contains("simulateTransaction"))
        XCTAssertFalse(fixture.transport.methods.contains("sendTransaction"))
    }

    func testClusterBoundSubmitExpectedClusterReachesExistingMissingKeyFailure() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        do {
            _ = try await fixture.service.submit(transfer: Self.nativeTransfer(chain: fixture.chain))
            XCTFail("No fixture mnemonic is available")
        } catch {}
        XCTAssertEqual(fixture.keys.reads, 1)
        XCTAssertFalse(fixture.transport.methods.contains("simulateTransaction"))
        XCTAssertFalse(fixture.transport.methods.contains("sendTransaction"))
    }

    func testClusterBoundFailoverSkipsWrongClusterQuote() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.devnet, fallback: true)
        let fee = try await fixture.service.estimateFee(for: Self.nativeTransfer(chain: fixture.chain))
        XCTAssertEqual(fee, BigUInt(5_000), "The wrong cluster's 777-lamport quote is not a healthy fallback")
        XCTAssertFalse(fixture.transport.requests.contains { $0.0 == ClusterTransport.custom && $0.1 == "getFeeForMessage" })
        XCTAssertTrue(fixture.transport.requests.contains { $0.0 == ClusterTransport.fallback && $0.1 == "getFeeForMessage" })
    }

    func testClusterBoundRecoveryCannotExpireUnboundRecordOnWrongCluster() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.devnet)
        let scope = SolanaPendingBroadcastScope(walletId: "public-cluster-fixture", chainId: UniversalWalletRegistry.solanaMainnet.chainId)
        let record = legacyClusterRecord(scope: scope)
        try fixture.store.save(record, for: scope)
        let key = SolanaPendingBroadcastStore.key(for: scope)
        let original = try XCTUnwrap(fixture.defaults.data(forKey: key))
        let broadcaster = SolanaTransactionBroadcaster(rpcClient: fixture.client, expectedPayer: Self.sender, store: fixture.store,
                                                       policy: .init(timeout: 0, pollInterval: 0))
        let state = await broadcaster.priorTransferState(scope: scope, rpcURL: ClusterTransport.custom)
        XCTAssertEqual(state, .unresolved(signature: record.signature))
        XCTAssertEqual(fixture.defaults.data(forKey: key), original, "Never delete unbound original bytes from current-cluster inference")
        XCTAssertEqual(SolanaPendingBroadcastStore(userDefaults: fixture.defaults, logger: nil).pending(for: scope), record)
    }

    func testClusterBoundRecoveryCannotReplayUnboundRecordOnWrongCluster() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.devnet)
        let scope = SolanaPendingBroadcastScope(walletId: "public-cluster-fixture", chainId: UniversalWalletRegistry.solanaMainnet.chainId)
        let record = legacyClusterRecord(scope: scope)
        try fixture.store.save(record, for: scope)
        let key = SolanaPendingBroadcastStore.key(for: scope)
        let original = try XCTUnwrap(fixture.defaults.data(forKey: key))
        let broadcaster = SolanaTransactionBroadcaster(rpcClient: fixture.client, expectedPayer: Self.sender, store: fixture.store,
                                                       policy: .init(timeout: 0, pollInterval: 0))
        _ = await broadcaster.retry(signature: record.signature, scope: scope,
                                    options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertFalse(fixture.transport.methods.contains("sendTransaction"))
        XCTAssertEqual(fixture.defaults.data(forKey: key), original)
    }

    func testClusterBoundQuoteDoesNotAuthorizeChangedEndpointKeyAccess() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        _ = try await fixture.service.estimateFee(for: Self.nativeTransfer(chain: fixture.chain))
        fixture.transport.genesis = ClusterTransport.devnet
        do {
            _ = try await fixture.service.submit(transfer: Self.nativeTransfer(chain: fixture.chain))
            XCTFail("Changed cluster must reject before keys")
        } catch {}
        XCTAssertEqual(fixture.keys.reads, 0)
        XCTAssertFalse(fixture.transport.methods.contains("sendTransaction"))
    }

    func testClusterBoundEveryRequestRechecksSameEndpointAndNoCrossEndpointCache() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet, fallback: true)
        let client = try fixture.client.bound(toGenesisHash: ClusterTransport.mainnet)
        _ = try await client.balance(address: Self.sender, commitment: .confirmed, rpcURL: ClusterTransport.custom)
        fixture.transport.genesis = ClusterTransport.devnet
        fixture.transport.fallbackGenesis = ClusterTransport.devnet
        let before = fixture.transport.methods.filter { $0 == "getBalance" }.count
        do {
            _ = try await client.balance(address: Self.sender, commitment: .confirmed, rpcURL: ClusterTransport.fallback)
            XCTFail("Neither the old endpoint attestation nor the healthy quote authorizes new reads")
        } catch {}
        XCTAssertEqual(fixture.transport.methods.filter { $0 == "getBalance" }.count, before)
        XCTAssertTrue(fixture.transport.requests.contains { $0.0 == ClusterTransport.fallback && $0.1 == "getGenesisHash" })
    }

    func testClusterBoundChangedEndpointAfterFeeCannotProduceSignedTransaction() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        fixture.transport.afterFee = { fixture.transport.genesis = ClusterTransport.devnet }
        do {
            _ = try await SolanaSendService(rpcClient: fixture.client).prepare(Self.request())
            XCTFail("Final cluster assertion must fail before signing returns a transaction")
        } catch let error as SolanaRpcClientError {
            XCTAssertEqual(error, .clusterMismatch)
        }
        XCTAssertTrue(fixture.transport.methods.contains("getFeeForMessage"))
        XCTAssertFalse(fixture.transport.methods.contains("simulateTransaction"))
        XCTAssertFalse(fixture.transport.methods.contains("sendTransaction"))
    }

    func testClusterBoundRecoveryPreservesOldUnboundBytesEvenOnMatchingEndpoint() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: "public-cluster-fixture", chainId: "solana:mainnet")
        let record = legacyClusterRecord(scope: scope)
        try fixture.store.save(record, for: scope)
        let original = fixture.defaults.data(forKey: SolanaPendingBroadcastStore.key(for: scope))
        let broadcaster = SolanaTransactionBroadcaster(rpcClient: fixture.client, expectedPayer: Self.sender, store: fixture.store,
                                                       policy: .init(timeout: 0, pollInterval: 0))
        let state = await broadcaster.priorTransferState(scope: scope, rpcURL: ClusterTransport.custom)
        let outcome = await broadcaster.retry(signature: record.signature, scope: scope,
                                              options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(state, .unresolved(signature: record.signature))
        XCTAssertEqual(outcome, .recoveryUnavailable(signature: record.signature))
        XCTAssertTrue(fixture.transport.requests.isEmpty)
        XCTAssertEqual(fixture.defaults.data(forKey: SolanaPendingBroadcastStore.key(for: scope)), original)
    }

    func testClusterBoundRecoveryCannotUseChangedClusterToClearOrReplayBoundBytes() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: "public-cluster-fixture", chainId: "solana:mainnet")
        let old = legacyClusterRecord(scope: scope)
        let record = SolanaPendingBroadcast(walletId: old.walletId, chainId: old.chainId, signature: old.signature,
            transactionBase64: old.transactionBase64, lastValidBlockHeight: old.lastValidBlockHeight,
            createdAt: old.createdAt, reportedAsSent: old.reportedAsSent, genesisHash: ClusterTransport.mainnet)
        try fixture.store.save(record, for: scope)
        _ = try await fixture.client.balance(address: Self.sender, commitment: .confirmed, rpcURL: ClusterTransport.custom)
        fixture.transport.genesis = ClusterTransport.devnet
        let original = fixture.defaults.data(forKey: SolanaPendingBroadcastStore.key(for: scope))
        let broadcaster = SolanaTransactionBroadcaster(rpcClient: fixture.client, expectedPayer: Self.sender, store: fixture.store,
                                                       policy: .init(timeout: 0, pollInterval: 0))
        let state = await broadcaster.priorTransferState(scope: scope, rpcURL: ClusterTransport.custom)
        let outcome = await broadcaster.retry(signature: record.signature, scope: scope,
                                              options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(state, .unresolved(signature: record.signature))
        XCTAssertEqual(outcome, .unknown(signature: record.signature))
        XCTAssertFalse(fixture.transport.methods.contains("sendTransaction"))
        XCTAssertFalse(fixture.transport.methods.contains("getBlockHeight"))
        XCTAssertEqual(fixture.defaults.data(forKey: SolanaPendingBroadcastStore.key(for: scope)), original)
        XCTAssertEqual(SolanaPendingBroadcastStore(userDefaults: fixture.defaults, logger: nil).pending(for: scope), record)
    }

    func testClusterBoundRecoveryHealthyBoundRecordCanResolveAndDoesNotPoisonAnotherNetworkClient() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: "public-cluster-fixture", chainId: "solana:mainnet")
        let old = legacyClusterRecord(scope: scope)
        let record = SolanaPendingBroadcast(walletId: old.walletId, chainId: old.chainId, signature: old.signature,
            transactionBase64: old.transactionBase64, lastValidBlockHeight: old.lastValidBlockHeight,
            createdAt: old.createdAt, reportedAsSent: false, genesisHash: ClusterTransport.mainnet, blockhashContextSlot: 100)
        try fixture.store.save(record, for: scope)
        let devnetClient = try fixture.client.bound(toGenesisHash: ClusterTransport.devnet)
        XCTAssertEqual(devnetClient.expectedGenesisHash, ClusterTransport.devnet)
        XCTAssertEqual(fixture.client.expectedGenesisHash, ClusterTransport.mainnet)
        let broadcaster = SolanaTransactionBroadcaster(rpcClient: fixture.client, expectedPayer: Self.sender, store: fixture.store,
                                                       policy: .init(timeout: 0, pollInterval: 0))
        let state = await broadcaster.priorTransferState(scope: scope, rpcURL: ClusterTransport.custom)
        // One host proved the expiry of a record signed long ago: it is released, but nothing
        // says the payment did not go out.
        XCTAssertEqual(state, .unverified(signature: record.signature))
        XCTAssertNil(fixture.store.pending(for: scope))
        XCTAssertFalse(fixture.transport.methods.contains("sendTransaction"))
    }

    func testClusterBoundServicePreservesUnavailableRecordBeforeAnyKeyOrRPCWork() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let record = legacyClusterRecord(scope: scope)
        try fixture.store.save(record, for: scope)
        let original = fixture.defaults.data(forKey: SolanaPendingBroadcastStore.key(for: scope))
        for retry in [false, true] {
            do {
                if retry { _ = try await fixture.service.retryUnresolvedTransfer(hash: record.signature) }
                else { _ = try await fixture.service.submit(transfer: Self.nativeTransfer(chain: fixture.chain)) }
                XCTFail("Unavailable original identity must stay explicit")
            } catch let TransferServiceError.solanaRecoveryUnavailable(signature) {
                XCTAssertEqual(signature, record.signature)
            }
        }
        XCTAssertEqual(fixture.keys.reads, 0)
        XCTAssertTrue(fixture.transport.requests.isEmpty)
        XCTAssertEqual(fixture.defaults.data(forKey: SolanaPendingBroadcastStore.key(for: scope)), original)
    }

    func testClusterBoundExplicitPrivateDefinitionUsesItsCapturedGenesis() async throws {
        let publicNetwork = UniversalWalletRegistry.solanaMainnet
        let privateNetwork = UniversalWalletRegistry.SolanaNetwork(
            id: "private-validator-fixture", genesisHash: Self.blockhash, chainId: publicNetwork.chainId,
            name: "Private deterministic fixture", indexerBaseURL: publicNetwork.indexerBaseURL,
            rpcURL: URL(string: ClusterTransport.custom)!, enabledByDefault: false, nativeAsset: publicNetwork.nativeAsset)
        let fixture = try clusterFixture(network: privateNetwork, genesis: Self.blockhash)
        let fee = try await fixture.service.estimateFee(for: Self.nativeTransfer(chain: fixture.chain))
        XCTAssertEqual(fee, BigUInt(5_000))
        fixture.transport.genesis = ClusterTransport.mainnet
        do {
            _ = try await fixture.service.estimateFee(for: Self.nativeTransfer(chain: fixture.chain))
            XCTFail("Public mainnet cannot stand in for the captured private cluster")
        } catch {}
        XCTAssertEqual(fixture.keys.reads, 0)
    }

    func testClusterBoundRejectsNetworkDefinitionForDifferentChain() throws {
        let chain = Self.solanaChain(network: UniversalWalletRegistry.solanaMainnet)
        XCTAssertThrowsError(try SolanaTransferService(wallet: Self.walletWithSolanaAccount(chainId: chain.chainId),
            chain: chain, rpcClient: FakeSolanaRpcClient(), networkDefinition: UniversalWalletRegistry.solanaDevnet))
    }

    func testUnreadablePendingReadKeepsOriginalActiveBytesAcrossStoreRecreation() throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let key = SolanaPendingBroadcastStore.key(for: scope)
        let bytes = Data("{interrupted-public-fixture".utf8)
        fixture.defaults.set(bytes, forKey: key)
        _ = fixture.store.pending(for: scope)
        let reopened = SolanaPendingBroadcastStore(userDefaults: fixture.defaults, logger: nil)
        _ = reopened.pending(for: scope)
        XCTAssertEqual(fixture.defaults.data(forKey: key), bytes)
        XCTAssertTrue(fixture.transport.requests.isEmpty)
        XCTAssertEqual(fixture.keys.reads, 0)
    }

    func testUnreadablePendingBlocksActualSubmitBeforeMnemonicAndRPC() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let key = SolanaPendingBroadcastStore.key(for: scope)
        let bytes = Data("{interrupted-public-fixture".utf8)
        fixture.defaults.set(bytes, forKey: key)
        do {
            _ = try await fixture.service.submit(transfer: Self.nativeTransfer(chain: fixture.chain))
            XCTFail("An unreadable pending payment must prevent a replacement")
        } catch {}
        XCTAssertEqual(fixture.keys.reads, 0)
        XCTAssertTrue(fixture.transport.requests.isEmpty)
        XCTAssertEqual(fixture.defaults.data(forKey: key), bytes)
    }

    func testWrongTypePendingBlocksActualSubmitWithoutTreatingItAsAbsence() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let key = SolanaPendingBroadcastStore.key(for: scope)
        fixture.defaults.set("wrong-type-public-fixture", forKey: key)
        do {
            _ = try await fixture.service.submit(transfer: Self.nativeTransfer(chain: fixture.chain))
            XCTFail("A present unreadable value is not an absent payment")
        } catch {}
        XCTAssertEqual(fixture.keys.reads, 0)
        XCTAssertTrue(fixture.transport.requests.isEmpty)
        XCTAssertEqual(fixture.defaults.string(forKey: key), "wrong-type-public-fixture")
    }

    func testUnreadablePendingCannotBeOverwrittenBySavingAnotherRecord() throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let key = SolanaPendingBroadcastStore.key(for: scope)
        let bytes = Data("{interrupted-public-fixture".utf8)
        fixture.defaults.set(bytes, forKey: key)
        XCTAssertThrowsError(try fixture.store.save(legacyClusterRecord(scope: scope), for: scope))
        XCTAssertEqual(fixture.defaults.data(forKey: key), bytes)
    }

    func testUnreadablePendingRetryPreservesBytesAndDoesNoRPC() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let key = SolanaPendingBroadcastStore.key(for: scope)
        let bytes = Data("{interrupted-public-fixture".utf8)
        fixture.defaults.set(bytes, forKey: key)
        do {
            _ = try await fixture.service.retryUnresolvedTransfer(hash: legacyClusterRecord(scope: scope).signature)
            XCTFail("An unreadable pending payment cannot be retried")
        } catch {}
        XCTAssertEqual(fixture.defaults.data(forKey: key), bytes)
        XCTAssertTrue(fixture.transport.requests.isEmpty)
        XCTAssertEqual(fixture.keys.reads, 0)
    }

    func testUnreadableOtherWalletDoesNotBlockHealthyScopeAdmission() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let other = SolanaPendingBroadcastScope(walletId: fixture.walletId + "-other", chainId: fixture.chain.chainId)
        let key = SolanaPendingBroadcastStore.key(for: other)
        let bytes = Data("{other-public-fixture".utf8)
        fixture.defaults.set(bytes, forKey: key)
        do {
            _ = try await fixture.service.submit(transfer: Self.nativeTransfer(chain: fixture.chain))
            XCTFail("This healthy fixture intentionally has no stored mnemonic")
        } catch {}
        XCTAssertEqual(fixture.keys.reads, 1)
        XCTAssertEqual(fixture.transport.methods, ["getGenesisHash"])
        XCTAssertEqual(fixture.defaults.data(forKey: key), bytes)
    }

    func testUnreadablePendingDoesNotDisableHealthyBalanceReading() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let key = SolanaPendingBroadcastStore.key(for: scope)
        let bytes = Data("{interrupted-public-fixture".utf8)
        fixture.defaults.set(bytes, forKey: key)
        let balance = try await SolanaRpcBalanceSync(rpcClient: fixture.client).balances(
            wallet: Self.sender, network: UniversalWalletRegistry.solanaMainnet, rpcURL: ClusterTransport.custom)
        XCTAssertEqual(balance.nativeBalance.amount, "2000000000")
        XCTAssertEqual(fixture.defaults.data(forKey: key), bytes)
        XCTAssertEqual(fixture.keys.reads, 0)
    }
    func testPreviouslySetAsidePendingBlocksActualSubmitBeforeMnemonicAndRPC() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let activeKey = SolanaPendingBroadcastStore.key(for: scope)
        let archiveKey = "solana.pending_broadcast.unreadable:\(scope.walletId):\(scope.chainId)"
        let bytes = Data("{preserved-by-the-original-store".utf8)
        fixture.defaults.set(bytes, forKey: archiveKey)
        XCTAssertNil(fixture.defaults.object(forKey: activeKey))
        do {
            _ = try await fixture.service.submit(transfer: Self.nativeTransfer(chain: fixture.chain))
            XCTFail("Previously set-aside unknown payment bytes cannot authorize a replacement")
        } catch {}
        XCTAssertEqual(fixture.keys.reads, 0)
        XCTAssertTrue(fixture.transport.requests.isEmpty)
        XCTAssertEqual(fixture.defaults.data(forKey: archiveKey), bytes)
        XCTAssertNil(fixture.defaults.object(forKey: activeKey))
    }

    func testUnreadablePendingProducesTypedNoSignatureFailureForSubmitAndRetry() async throws {
        for archived in [false, true] {
            let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
            let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
            let key = archived ? "solana.pending_broadcast.unreadable:\(scope.walletId):\(scope.chainId)"
                : SolanaPendingBroadcastStore.key(for: scope)
            fixture.defaults.set(Data("{public unreadable fixture".utf8), forKey: key)
            do {
                _ = try await fixture.service.submit(transfer: Self.nativeTransfer(chain: fixture.chain))
                XCTFail("Must reject unreadable pending data")
            } catch TransferServiceError.solanaRecoveryRecordUnreadable {} catch {
                XCTFail("Unexpected submit error: \(error)")
            }
            do {
                _ = try await fixture.service.retryUnresolvedTransfer(hash: legacyClusterRecord(scope: scope).signature)
                XCTFail("Must reject retry without a trustworthy stored identity")
            } catch TransferServiceError.solanaRecoveryRecordUnreadable {} catch {
                XCTFail("Unexpected retry error: \(error)")
            }
            XCTAssertEqual(fixture.keys.reads, 0)
            XCTAssertTrue(fixture.transport.requests.isEmpty)
        }
    }

    func testUnreadableStorePreservesHistoricalAndNewerActiveBytesAgainstSaveAndClear() throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let record = legacyClusterRecord(scope: scope)
        try fixture.store.save(record, for: scope)
        XCTAssertEqual(fixture.store.readState(for: scope), .pending(record))
        let key = SolanaPendingBroadcastStore.key(for: scope)
        let active = try XCTUnwrap(fixture.defaults.data(forKey: key))
        let archiveKey = "solana.pending_broadcast.unreadable:\(scope.walletId):\(scope.chainId)"
        let archived = Data("{older unknown transfer".utf8)
        fixture.defaults.set(archived, forKey: archiveKey)
        let reopened = SolanaPendingBroadcastStore(userDefaults: fixture.defaults, logger: nil)
        XCTAssertEqual(reopened.readState(for: scope), .unreadable)
        XCTAssertThrowsError(try reopened.save(record, for: scope)) {
            XCTAssertEqual($0 as? SolanaPendingBroadcastStoreError, .unreadableRecord)
        }
        reopened.clear(signature: record.signature, for: scope)
        XCTAssertEqual(fixture.defaults.data(forKey: key), active)
        XCTAssertEqual(fixture.defaults.data(forKey: archiveKey), archived)
        let other = SolanaPendingBroadcastScope(walletId: scope.walletId + "-other", chainId: scope.chainId)
        XCTAssertEqual(reopened.readState(for: other), .absent)
        try reopened.save(legacyClusterRecord(scope: other), for: other)
        XCTAssertEqual(reopened.readState(for: other), .pending(legacyClusterRecord(scope: other)))
    }

    func testUnreadableDirectBroadcasterDoesNotResolveRetryOrTransmitPreparedBytes() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let key = SolanaPendingBroadcastStore.key(for: scope)
        let bytes = Data("{preserved unreadable record".utf8)
        fixture.defaults.set(bytes, forKey: key)
        let broadcaster = SolanaTransactionBroadcaster(
            rpcClient: try fixture.client.bound(toGenesisHash: ClusterTransport.mainnet), expectedPayer: Self.sender, store: fixture.store)
        let record = legacyClusterRecord(scope: scope)
        let signed = SignedSolanaTransaction(requiredSignatures: 1, signedTransaction: Data("impossible public bytes".utf8),
            signedTransactionBase64: record.transactionBase64, signatureBase58: record.signature,
            signer: Self.sender, version: .legacy)
        let prior = await broadcaster.priorTransferState(scope: scope, rpcURL: ClusterTransport.custom)
        XCTAssertEqual(prior, .unreadableRecord)
        let retry = await broadcaster.retry(signature: record.signature, scope: scope,
            options: SolanaBroadcastOptions(preflightCommitment: .confirmed), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(retry, .recoveryRecordUnreadable)
        let broadcast = try await broadcaster.broadcast(signed, lastValidBlockHeight: 99, scope: scope,
            options: SolanaBroadcastOptions(preflightCommitment: .confirmed), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(broadcast, .recoveryRecordUnreadable)
        XCTAssertTrue(fixture.transport.requests.isEmpty)
        XCTAssertEqual(fixture.defaults.data(forKey: key), bytes)
    }


    func testSemanticPendingInvalidBase64BlocksSubmitAndPreservesExactBytes() async throws {
        try await assertSemanticSubmitBlocked(changes: ["transactionBase64": "not base64!"])
    }

    func testSemanticPendingSignatureMismatchBlocksSubmitAndPreservesExactBytes() async throws {
        try await assertSemanticSubmitBlocked(changes: ["signature": String(repeating: "1", count: 64)])
    }

    func testSemanticPendingModifiedSignedMessageBlocksSubmitAndPreservesExactBytes() async throws {
        let record = try semanticPublicRecord(scope: SolanaPendingBroadcastScope(walletId: "public", chainId: "solana:mainnet"))
        var wire = try XCTUnwrap(Data(base64Encoded: record.transactionBase64))
        wire[wire.count - 1] ^= 1 // Change a valid native-transfer message after it was signed.
        let parsed = try SolanaTransactionSigner.parseSerializedTransaction(wire)
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let signature = wire.subdata(in: parsed.signaturesOffset ..< parsed.signaturesOffset + 64)
        XCTAssertFalse(try SolanaSigner.verifyMessage(publicKey: account.publicKey, message: parsed.messageBytes, signature: signature))
        try await assertSemanticSubmitBlocked(changes: ["transactionBase64": wire.base64EncodedString()])
    }

    func testSemanticPendingNegativeHeightBlocksSubmitAndPreservesExactBytes() async throws {
        try await assertSemanticSubmitBlocked(changes: ["lastValidBlockHeight": -1])
    }

    func testSemanticPendingWrongWalletCannotBeClearedOrOverwritten() throws {
        try assertSemanticScopeProtected(changes: ["walletId": "different-public-wallet"])
    }

    func testSemanticPendingWrongChainCannotBeClearedOrOverwritten() throws {
        try assertSemanticScopeProtected(changes: ["chainId": "solana:devnet"])
    }

    func testSemanticPendingRetryRejectsDifferentValidSignedBytes() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let first = try semanticPublicRecord(scope: scope)
        let second = try semanticPublicRecord(scope: scope, amount: 2)
        XCTAssertNotEqual(first.signature, second.signature)
        let bytes = try semanticEncodedRecord(first, changes: ["transactionBase64": second.transactionBase64])
        let key = SolanaPendingBroadcastStore.key(for: scope)
        fixture.defaults.set(bytes, forKey: key)
        do {
            _ = try await fixture.service.retryUnresolvedTransfer(hash: first.signature)
            XCTFail("A retained signature must not authorize a different signed transaction")
        } catch {}
        XCTAssertTrue(fixture.transport.requests.isEmpty, "No lookup or retry uses inconsistent identity")
        XCTAssertEqual(fixture.defaults.data(forKey: key), bytes)
        XCTAssertEqual(fixture.keys.reads, 0)
    }

    func testSemanticPendingLowPositiveHeightCannotExpireLiveSignedBlockhash() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let record = try semanticPublicRecord(scope: scope) // Stored 99 conflicts with local height 1000 and still-valid wire blockhash.
        fixture.transport.blockhashIsValid = true
        let bytes = try semanticEncodedRecord(record)
        let key = SolanaPendingBroadcastStore.key(for: scope)
        fixture.defaults.set(bytes, forKey: key)
        do {
            _ = try await fixture.service.submit(transfer: Self.nativeTransfer(chain: fixture.chain))
            XCTFail("Unsigned height metadata cannot establish that the signed blockhash expired")
        } catch {}
        XCTAssertEqual(fixture.keys.reads, 0)
        XCTAssertEqual(fixture.defaults.data(forKey: key), bytes)
        XCTAssertTrue(fixture.transport.methods.contains("isBlockhashValid"), "Check the exact retained blockhash before clearing on expiry")
        XCTAssertFalse(fixture.transport.methods.contains("sendTransaction"))
    }

    func testSemanticPendingDifferentVerifiedPayerUnderCorrectScopeBlocksSubmit() async throws {
        try await assertSemanticOtherPayerBlocked(retry: false)
    }

    func testSemanticPendingDifferentVerifiedPayerUnderCorrectScopeBlocksRetry() async throws {
        try await assertSemanticOtherPayerBlocked(retry: true)
    }

    func testSemanticDirectBroadcastPreservesExistingDifferentVerifiedPayer() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let path = "m/44'/501'/1'/0'"
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic, derivationPath: path)
        let otherUnsigned = try SolanaTransferTransactionBuilder.buildNativeTransfer(senderAddress: account.address,
            recipientAddress: Self.recipient, lamports: 1, recentBlockhash: Self.blockhash)
        let otherSigned = try SolanaTransactionSigner.signSerializedTransaction(mnemonic: Self.mnemonic,
            transactionBase64: otherUnsigned.transactionBase64, expectedSigner: account.address, derivationPath: path)
        let existing = SolanaPendingBroadcast(walletId: scope.walletId, chainId: scope.chainId,
            signature: otherSigned.signatureBase58, transactionBase64: otherSigned.signedTransactionBase64,
            lastValidBlockHeight: 2_000, createdAt: Date(timeIntervalSince1970: 1_760_000_000),
            reportedAsSent: false, genesisHash: ClusterTransport.mainnet)
        let original = try semanticEncodedRecord(existing)
        let key = SolanaPendingBroadcastStore.key(for: scope)
        fixture.defaults.set(original, forKey: key)
        let incoming = try semanticPublicRecord(scope: scope)
        let wire = try XCTUnwrap(Data(base64Encoded: incoming.transactionBase64))
        let signed = SignedSolanaTransaction(requiredSignatures: 1, signedTransaction: wire,
            signedTransactionBase64: incoming.transactionBase64, signatureBase58: incoming.signature,
            signer: Self.sender, version: .legacy)
        let broadcaster = SolanaTransactionBroadcaster(rpcClient: fixture.client, expectedPayer: Self.sender,
            store: fixture.store, policy: .init(timeout: 0, pollInterval: 0))
        let outcome = try await broadcaster.broadcast(signed, lastValidBlockHeight: 99, scope: scope,
            options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(outcome, .recoveryRecordUnreadable)
        XCTAssertEqual(fixture.defaults.data(forKey: key), original)
        XCTAssertTrue(fixture.transport.requests.isEmpty)
        XCTAssertEqual(fixture.keys.reads, 0)
    }

    private func assertSemanticOtherPayerBlocked(retry: Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let path = "m/44'/501'/1'/0'"
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic, derivationPath: path)
        XCTAssertNotEqual(account.address, Self.sender, file: file, line: line)
        let unsigned = try SolanaTransferTransactionBuilder.buildNativeTransfer(senderAddress: account.address,
            recipientAddress: Self.recipient, lamports: 1, recentBlockhash: Self.blockhash)
        let signed = try SolanaTransactionSigner.signSerializedTransaction(mnemonic: Self.mnemonic,
            transactionBase64: unsigned.transactionBase64, expectedSigner: account.address, derivationPath: path)
        let parsed = try SolanaTransactionSigner.parseSerializedTransaction(signed.signedTransaction)
        let signature = signed.signedTransaction.subdata(in: parsed.signaturesOffset ..< parsed.signaturesOffset + 64)
        XCTAssertTrue(try SolanaSigner.verifyMessage(publicKey: account.publicKey, message: parsed.messageBytes,
            signature: signature), file: file, line: line)
        let record = SolanaPendingBroadcast(walletId: scope.walletId, chainId: scope.chainId,
            signature: signed.signatureBase58, transactionBase64: signed.signedTransactionBase64,
            lastValidBlockHeight: 99, createdAt: Date(timeIntervalSince1970: 1_760_000_000),
            reportedAsSent: false, genesisHash: ClusterTransport.mainnet)
        let bytes = try semanticEncodedRecord(record)
        let key = SolanaPendingBroadcastStore.key(for: scope)
        fixture.defaults.set(bytes, forKey: key)
        do {
            if retry {
                _ = try await fixture.service.retryUnresolvedTransfer(hash: record.signature)
            } else {
                _ = try await fixture.service.submit(transfer: Self.nativeTransfer(chain: fixture.chain))
            }
            XCTFail("A different verified payer must not authorize this wallet's recovery", file: file, line: line)
        } catch {}
        XCTAssertEqual(fixture.keys.reads, 0, file: file, line: line)
        XCTAssertTrue(fixture.transport.requests.isEmpty, "Payer identity must be checked locally before RPC", file: file, line: line)
        XCTAssertEqual(fixture.defaults.data(forKey: key), bytes, file: file, line: line)
    }

    func testSemanticHealthySignedPendingRecordBlocksReplacementWithoutKeyRead() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let record = try semanticPublicRecord(scope: scope, height: 2_000)
        fixture.transport.blockhashIsValid = true
        let bytes = try semanticEncodedRecord(record)
        let key = SolanaPendingBroadcastStore.key(for: scope)
        fixture.defaults.set(bytes, forKey: key)
        do {
            _ = try await fixture.service.submit(transfer: Self.nativeTransfer(chain: fixture.chain))
            XCTFail("A healthy unresolved payment still blocks replacement")
        } catch TransferServiceError.solanaPriorTransferUnresolved(let signature) {
            XCTAssertEqual(signature, record.signature)
        } catch { XCTFail("Unexpected healthy pending result: \(error)") }
        XCTAssertEqual(fixture.defaults.data(forKey: key), bytes)
        XCTAssertEqual(fixture.keys.reads, 0)
        XCTAssertTrue(fixture.transport.methods.contains("getSignatureStatuses"))
        XCTAssertFalse(fixture.transport.methods.contains("sendTransaction"))
    }

    func testSemanticHealthyExpiredSignedRecordAllowsIndependentMissingMnemonicFailure() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let record = try semanticPublicRecord(scope: scope)
        fixture.transport.blockhashIsValid = false
        fixture.defaults.set(try semanticEncodedRecord(record, changes: ["blockhashContextSlot": 100]), forKey: SolanaPendingBroadcastStore.key(for: scope))
        try await assertReleasedUnverified(record, fixture: fixture, scope: scope)
        do {
            _ = try await fixture.service.submit(transfer: Self.nativeTransfer(chain: fixture.chain))
            XCTFail("Healthy fixture intentionally has no stored mnemonic")
        } catch {}
        XCTAssertNil(fixture.defaults.object(forKey: SolanaPendingBroadcastStore.key(for: scope)))
        XCTAssertEqual(fixture.keys.reads, 1)
        XCTAssertTrue(fixture.transport.methods.contains("getSignatureStatuses"))
        XCTAssertFalse(fixture.transport.methods.contains("sendTransaction"))
    }

    func testSemanticHealthySignedRecordRoundTripsAndClearsOnlyItsSignature() throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let record = try semanticPublicRecord(scope: scope)
        try fixture.store.save(record, for: scope)
        let reopened = SolanaPendingBroadcastStore(userDefaults: fixture.defaults, logger: nil)
        XCTAssertEqual(reopened.readState(for: scope), .pending(record))
        reopened.clear(signature: "different", for: scope)
        XCTAssertEqual(reopened.readState(for: scope), .pending(record))
        reopened.clear(signature: record.signature, for: scope)
        XCTAssertEqual(reopened.readState(for: scope), .absent)
        XCTAssertTrue(fixture.transport.requests.isEmpty)
    }

    func testSemanticStoreRejectsInvalidNewRecordWithoutOverwritingHealthyBytes() throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let invalid = try semanticPublicRecord(scope: scope, height: -1)
        let key = SolanaPendingBroadcastStore.key(for: scope)
        XCTAssertThrowsError(try fixture.store.save(invalid, for: scope))
        XCTAssertNil(fixture.defaults.object(forKey: key))
        let valid = try semanticPublicRecord(scope: scope)
        try fixture.store.save(valid, for: scope)
        let original = fixture.defaults.data(forKey: key)
        XCTAssertThrowsError(try fixture.store.save(invalid, for: scope))
        XCTAssertEqual(fixture.defaults.data(forKey: key), original)
        XCTAssertEqual(fixture.store.readState(for: scope), .pending(valid))
    }

    func testSemanticStoreStillAcceptsHealthyIndependentWalletAndLegacyUnboundRecord() throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let originalScope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        fixture.defaults.set(try semanticEncodedRecord(semanticPublicRecord(scope: originalScope),
            changes: ["signature": "inconsistent"]), forKey: SolanaPendingBroadcastStore.key(for: originalScope))
        let other = SolanaPendingBroadcastScope(walletId: originalScope.walletId + "-independent", chainId: originalScope.chainId)
        let legacy = legacyClusterRecord(scope: other)
        try fixture.store.save(legacy, for: other)
        XCTAssertEqual(fixture.store.readState(for: originalScope), .unreadable)
        XCTAssertEqual(fixture.store.readState(for: other), .pending(legacy))
        XCTAssertNil(legacy.genesisHash)
        XCTAssertTrue(fixture.transport.requests.isEmpty)
    }

    private func assertSemanticSubmitBlocked(changes: [String: Any], file: StaticString = #filePath, line: UInt = #line) async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let record = try semanticPublicRecord(scope: scope)
        let bytes = try semanticEncodedRecord(record, changes: changes)
        let key = SolanaPendingBroadcastStore.key(for: scope)
        fixture.defaults.set(bytes, forKey: key)
        do {
            _ = try await fixture.service.submit(transfer: Self.nativeTransfer(chain: fixture.chain))
            XCTFail("An inconsistent decoded payment must not authorize a replacement", file: file, line: line)
        } catch {}
        XCTAssertEqual(fixture.keys.reads, 0, file: file, line: line)
        XCTAssertTrue(fixture.transport.requests.isEmpty, "Invalid local data must be refused before RPC", file: file, line: line)
        XCTAssertEqual(fixture.defaults.data(forKey: key), bytes, file: file, line: line)
    }

    private func assertSemanticScopeProtected(changes: [String: Any], file: StaticString = #filePath, line: UInt = #line) throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let record = try semanticPublicRecord(scope: scope)
        let bytes = try semanticEncodedRecord(record, changes: changes)
        let key = SolanaPendingBroadcastStore.key(for: scope)
        fixture.defaults.set(bytes, forKey: key)
        XCTAssertEqual(fixture.store.readState(for: scope), .unreadable, file: file, line: line)
        fixture.store.clear(signature: record.signature, for: scope)
        XCTAssertEqual(fixture.defaults.data(forKey: key), bytes, file: file, line: line)
        XCTAssertThrowsError(try fixture.store.save(record, for: scope), file: file, line: line)
        XCTAssertEqual(fixture.defaults.data(forKey: key), bytes, file: file, line: line)
    }

    func testExpiryFalseWithoutOriginalBlockProvenancePreservesRecord() async throws {
        try await assertExpiryRecordPreserved(hint: nil)
    }

    func testExpiryFalseAtWrongFinalizedBlockPreservesRecord() async throws {
        try await assertExpiryRecordPreserved { $0.finalizedBlockhash = Self.recipient }
    }

    func testExpiryFalseWithPrunedFinalizedBlockPreservesRecord() async throws {
        try await assertExpiryRecordPreserved { $0.finalizedBlockhash = nil }
    }

    func testExpiryFalseBeforeProvenBlockContextPreservesRecord() async throws {
        try await assertExpiryRecordPreserved { $0.validitySlot = 99 }
    }

    func testExpiryFalseWithLaggingStatusObservationPreservesRecord() async throws {
        try await assertExpiryRecordPreserved { $0.statusSlot = 999 }
    }

    func testExpiryStillValidFinalizedBlockPreservesRecordDespiteLowHeight() async throws {
        try await assertExpiryRecordPreserved { $0.blockhashIsValid = true }
    }

    func testExpiryConflictingHealthyEndpointCannotBeOverruledByExpiredEndpoint() async throws {
        try await assertExpiryRecordPreserved(fallback: true) { $0.fallbackBlockhashIsValid = true }
    }

    func testExpiryOfflineProvenancePreservesRecordAndIndependentWalletBalance() async throws {
        try await assertExpiryRecordPreserved { $0.failExpiryRequests = true }
    }

    func testExpiryProvenFinalizedHashAllowsNewAttemptDespiteHighStoredHeight() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let record = try semanticPublicRecord(scope: scope, height: 9_999_999)
        fixture.defaults.set(try semanticEncodedRecord(record, changes: ["blockhashContextSlot": 100]),
                             forKey: SolanaPendingBroadcastStore.key(for: scope))
        try await assertReleasedUnverified(record, fixture: fixture, scope: scope)
        do { _ = try await fixture.service.submit(transfer: Self.nativeTransfer(chain: fixture.chain)); XCTFail("Fixture has no mnemonic") }
        catch {}
        XCTAssertNil(fixture.defaults.object(forKey: SolanaPendingBroadcastStore.key(for: scope)))
        XCTAssertEqual(fixture.keys.reads, 1, "Only independently proven expiry permits a fresh key read")
        XCTAssertFalse(fixture.transport.methods.contains("sendTransaction"))
    }

    func testExpiryProvenFinalizedHashHealthyLowHeightAllowsNewAttempt() async throws {
        // Two distinct hosts prove the expiry of a record signed just now: "not sent", so the
        // new transfer goes ahead in the same call.
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet, fallback: true)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let record = try semanticPublicRecord(scope: scope)
        let signedNow = Int64(Date().timeIntervalSince1970 * 1000)
        fixture.defaults.set(try semanticEncodedRecord(record, changes: ["blockhashContextSlot": 100, "createdAt": signedNow]),
                             forKey: SolanaPendingBroadcastStore.key(for: scope))
        do { _ = try await fixture.service.submit(transfer: Self.nativeTransfer(chain: fixture.chain)); XCTFail("Fixture has no mnemonic") }
        catch {}
        XCTAssertNil(fixture.defaults.object(forKey: SolanaPendingBroadcastStore.key(for: scope)))
        XCTAssertEqual(fixture.keys.reads, 1)
        XCTAssertFalse(fixture.transport.methods.contains("sendTransaction"))
    }

    func testExpiryHealthyLandedRecordResolvesWithoutExpiryProvenance() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        fixture.transport.signatureLanded = true
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let record = try semanticPublicRecord(scope: scope)
        fixture.defaults.set(try semanticEncodedRecord(record), forKey: SolanaPendingBroadcastStore.key(for: scope))
        let broadcaster = SolanaTransactionBroadcaster(rpcClient: fixture.client, expectedPayer: Self.sender, store: fixture.store)
        let result = await broadcaster.priorTransferState(scope: scope, rpcURL: ClusterTransport.custom)
        XCTAssertEqual(result, .sentAfterAll(signature: record.signature))
        XCTAssertNil(fixture.defaults.object(forKey: SolanaPendingBroadcastStore.key(for: scope)))
        XCTAssertEqual(fixture.keys.reads, 0)
        XCTAssertFalse(fixture.transport.methods.contains("sendTransaction"))
    }

    func testExpiryDurableNonceMarkerCannotUseRecentBlockhashExpiry() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let unsigned = try SolanaTransferTransactionBuilder.buildNativeTransfer(senderAddress: Self.sender,
            recipientAddress: Self.recipient, lamports: 1, recentBlockhash: Self.blockhash)
        var wire = try XCTUnwrap(Data(base64Encoded: unsigned.transactionBase64))
        // Public signed first-instruction marker, not an on-chain nonce account fixture.
        XCTAssertEqual(Array(wire.suffix(12).prefix(4)), [2, 0, 0, 0])
        wire[wire.count - 12] = 4
        let signed = try SolanaTransactionSigner.signSerializedTransaction(mnemonic: Self.mnemonic,
            transactionBase64: wire.base64EncodedString(), expectedSigner: Self.sender)
        let parsed = try SolanaTransactionSigner.verifySerializedTransaction(base64: signed.signedTransactionBase64,
            expectedSignature: signed.signatureBase58)
        XCTAssertFalse(parsed.allowsRecentBlockhashExpiry)
        let record = SolanaPendingBroadcast(walletId: scope.walletId, chainId: scope.chainId,
            signature: signed.signatureBase58, transactionBase64: signed.signedTransactionBase64,
            lastValidBlockHeight: 1, createdAt: Date(), reportedAsSent: false,
            genesisHash: ClusterTransport.mainnet, blockhashContextSlot: 100)
        let original = try semanticEncodedRecord(record)
        let key = SolanaPendingBroadcastStore.key(for: scope)
        fixture.defaults.set(original, forKey: key)
        do { _ = try await fixture.service.submit(transfer: Self.nativeTransfer(chain: fixture.chain)); XCTFail("Nonce expiry is unproven") }
        catch {}
        XCTAssertEqual(fixture.keys.reads, 0)
        XCTAssertEqual(fixture.defaults.data(forKey: key), original)
        XCTAssertFalse(fixture.transport.methods.contains("sendTransaction"))
    }

    func testExpiryProofRequestsUseFinalizedContextAndExactSignedHash() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let record = try semanticPublicRecord(scope: scope)
        try fixture.store.save(SolanaPendingBroadcast(walletId: scope.walletId, chainId: scope.chainId,
            signature: record.signature, transactionBase64: record.transactionBase64, lastValidBlockHeight: 1,
            createdAt: record.createdAt, reportedAsSent: false, genesisHash: ClusterTransport.mainnet,
            blockhashContextSlot: 100), for: scope)
        let broadcaster = SolanaTransactionBroadcaster(rpcClient: fixture.client, expectedPayer: Self.sender, store: fixture.store)
        let result = await broadcaster.priorTransferState(scope: scope, rpcURL: ClusterTransport.custom)
        XCTAssertEqual(result, .unverified(signature: record.signature), "One host and a record signed long ago")
        let block = try XCTUnwrap(fixture.transport.rpcBodies.first { $0["method"] as? String == "getBlock" })
        let blockParams = try XCTUnwrap(block["params"] as? [Any])
        XCTAssertEqual(blockParams[0] as? Int, 100)
        XCTAssertEqual((blockParams[1] as? [String: Any])?["commitment"] as? String, "finalized")
        let validity = try XCTUnwrap(fixture.transport.rpcBodies.first { $0["method"] as? String == "isBlockhashValid" })
        let params = try XCTUnwrap(validity["params"] as? [Any])
        XCTAssertEqual(params[0] as? String, Self.blockhash)
        XCTAssertEqual((params[1] as? [String: Any])?["commitment"] as? String, "finalized")
        XCTAssertEqual((params[1] as? [String: Any])?["minContextSlot"] as? Int, 100)
        let methods = fixture.transport.methods
        XCTAssertLessThan(try XCTUnwrap(methods.firstIndex(of: "isBlockhashValid")), try XCTUnwrap(methods.lastIndex(of: "getSignatureStatuses")))
        XCTAssertFalse(methods.contains("getBlockHeight"), "Unsigned stored height is never an expiry authority")
        XCTAssertEqual(fixture.keys.reads, 0)
    }

    func testExpiryProofReattestsClusterAfterFinalizedBlockAndPreservesRecord() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let bytes = try semanticEncodedRecord(semanticPublicRecord(scope: scope), changes: ["blockhashContextSlot": 100])
        let key = SolanaPendingBroadcastStore.key(for: scope)
        fixture.defaults.set(bytes, forKey: key)
        fixture.transport.afterBlock = { fixture.transport.genesis = ClusterTransport.devnet }
        do { _ = try await fixture.service.submit(transfer: Self.nativeTransfer(chain: fixture.chain)); XCTFail("Cluster changed") }
        catch {}
        XCTAssertTrue(fixture.transport.methods.contains("getBlock"))
        XCTAssertFalse(fixture.transport.methods.contains("isBlockhashValid"))
        XCTAssertEqual(fixture.keys.reads, 0)
        XCTAssertEqual(fixture.defaults.data(forKey: key), bytes)
        XCTAssertFalse(fixture.transport.methods.contains("sendTransaction"))
    }

    func testExpiryPreviousMatchingProofDoesNotAuthorizeLaterChangedCluster() async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let record = try semanticPublicRecord(scope: scope)
        let bytes = try semanticEncodedRecord(record, changes: ["blockhashContextSlot": 100])
        let key = SolanaPendingBroadcastStore.key(for: scope)
        fixture.defaults.set(bytes, forKey: key)
        let broadcaster = SolanaTransactionBroadcaster(rpcClient: fixture.client, expectedPayer: Self.sender, store: fixture.store)
        fixture.transport.blockhashIsValid = true
        let first = await broadcaster.priorTransferState(scope: scope, rpcURL: ClusterTransport.custom)
        XCTAssertEqual(first, .unresolved(signature: record.signature))
        let before = fixture.transport.methods.count
        fixture.transport.genesis = ClusterTransport.devnet
        fixture.transport.blockhashIsValid = false
        let second = await broadcaster.priorTransferState(scope: scope, rpcURL: ClusterTransport.custom)
        XCTAssertEqual(second, .unresolved(signature: record.signature))
        XCTAssertEqual(Array(fixture.transport.methods.dropFirst(before)), ["getGenesisHash"])
        XCTAssertEqual(fixture.defaults.data(forKey: key), bytes)
        XCTAssertEqual(fixture.keys.reads, 0)
    }

    private func assertExpiryRecordPreserved(hint: Int64? = 100, fallback: Bool = false,
        configure: (ClusterTransport) -> Void = { _ in }, file: StaticString = #filePath, line: UInt = #line) async throws {
        let fixture = try clusterFixture(genesis: ClusterTransport.mainnet, fallback: fallback)
        configure(fixture.transport)
        let scope = SolanaPendingBroadcastScope(walletId: fixture.walletId, chainId: fixture.chain.chainId)
        let record = try semanticPublicRecord(scope: scope)
        let changes: [String: Any] = hint.map { ["blockhashContextSlot": $0] } ?? [:]
        let original = try semanticEncodedRecord(record, changes: changes)
        let key = SolanaPendingBroadcastStore.key(for: scope)
        fixture.defaults.set(original, forKey: key)
        do { _ = try await fixture.service.submit(transfer: Self.nativeTransfer(chain: fixture.chain)); XCTFail("Unproven expiry", file: file, line: line) }
        catch {}
        XCTAssertEqual(fixture.keys.reads, 0, "Unproven expiry must not authorize a new signature", file: file, line: line)
        XCTAssertEqual(fixture.defaults.data(forKey: key), original, file: file, line: line)
        XCTAssertFalse(fixture.transport.methods.contains("sendTransaction"), file: file, line: line)
        let reopened = SolanaPendingBroadcastStore(userDefaults: fixture.defaults, logger: nil)
        XCTAssertNotEqual(reopened.readState(for: scope), .absent, file: file, line: line)
        let independent = SolanaPendingBroadcastScope(walletId: scope.walletId + "-healthy", chainId: scope.chainId)
        XCTAssertEqual(reopened.readState(for: independent), .absent, file: file, line: line)
        let balance = try await fixture.client.balance(address: Self.recipient, commitment: .confirmed, rpcURL: ClusterTransport.custom)
        XCTAssertEqual(balance, 2_000_000_000, file: file, line: line)
    }

    /// One host proved the expiry of a record signed long ago: the transfer stops with
    /// "could not be verified", nothing is read or signed, and the record is released.
    private func assertReleasedUnverified(
        _ record: SolanaPendingBroadcast,
        fixture: ClusterFixture,
        scope: SolanaPendingBroadcastScope,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        do {
            _ = try await fixture.service.submit(transfer: Self.nativeTransfer(chain: fixture.chain))
            XCTFail("Expected the transfer to stop", file: file, line: line)
        } catch let TransferServiceError.solanaPriorTransferUnverified(signature) {
            XCTAssertEqual(signature, record.signature, file: file, line: line)
        }
        XCTAssertEqual(fixture.keys.reads, 0, "Nothing new is read before the user confirms again", file: file, line: line)
        XCTAssertNil(fixture.defaults.object(forKey: SolanaPendingBroadcastStore.key(for: scope)), file: file, line: line)
    }

    private func semanticPublicRecord(scope: SolanaPendingBroadcastScope, amount: Int64 = 1, height: Int64 = 99) throws -> SolanaPendingBroadcast {
        let unsigned = try SolanaTransferTransactionBuilder.buildNativeTransfer(senderAddress: Self.sender,
            recipientAddress: Self.recipient, lamports: amount, recentBlockhash: Self.blockhash)
        let signed = try SolanaTransactionSigner.signSerializedTransaction(mnemonic: Self.mnemonic,
            transactionBase64: unsigned.transactionBase64, expectedSigner: Self.sender)
        let parsed = try SolanaTransactionSigner.parseSerializedTransaction(signed.signedTransaction)
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: Self.mnemonic)
        let signature = signed.signedTransaction.subdata(in: parsed.signaturesOffset ..< parsed.signaturesOffset + 64)
        XCTAssertTrue(try SolanaSigner.verifyMessage(publicKey: account.publicKey, message: parsed.messageBytes, signature: signature))
        return SolanaPendingBroadcast(walletId: scope.walletId, chainId: scope.chainId, signature: signed.signatureBase58,
            transactionBase64: signed.signedTransactionBase64, lastValidBlockHeight: height,
            createdAt: Date(timeIntervalSince1970: 1_760_000_000), reportedAsSent: false, genesisHash: ClusterTransport.mainnet)
    }

    private func semanticEncodedRecord(_ record: SolanaPendingBroadcast, changes: [String: Any] = [:]) throws -> Data {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .millisecondsSince1970
        var fields = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(record)) as? [String: Any])
        changes.forEach { fields[$0] = $1 }
        let bytes = try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970
        _ = try decoder.decode(SolanaPendingBroadcast.self, from: bytes) // Every failing fixture genuinely decodes.
        return bytes
    }

    // Reuse the exact public wire fixture: record equality must not depend on a fresh signature.
    private static let legacyClusterSigned: SignedSolanaTransaction = {
        let unsigned = try! SolanaTransferTransactionBuilder.buildNativeTransfer(senderAddress: sender,
            recipientAddress: recipient, lamports: 1, recentBlockhash: blockhash)
        return try! SolanaTransactionSigner.signSerializedTransaction(mnemonic: mnemonic,
            transactionBase64: unsigned.transactionBase64, expectedSigner: sender)
    }()

    private func legacyClusterRecord(scope: SolanaPendingBroadcastScope) -> SolanaPendingBroadcast {
        let valid = Self.legacyClusterSigned
        return SolanaPendingBroadcast(walletId: scope.walletId, chainId: scope.chainId,
            signature: valid.signatureBase58, transactionBase64: valid.signedTransactionBase64,
            lastValidBlockHeight: 99, createdAt: Date(timeIntervalSince1970: 1_760_000_000), reportedAsSent: false)
    }

    private func clusterFixture(network: UniversalWalletRegistry.SolanaNetwork = UniversalWalletRegistry.solanaMainnet,
                                genesis: String, fallback: Bool = false) throws -> ClusterFixture {
        let urls = [ClusterTransport.custom] + (fallback ? [ClusterTransport.fallback] : [])
        let chain = Self.solanaChain(network: network, nodes: urls.map {
            ChainNodeModel(url: URL(string: $0)!, name: "Public deterministic fixture", apikey: nil)
        })
        let transport = ClusterTransport(genesis: genesis, wrongQuote: fallback)
        let client = try SolanaFailoverRpcClient(endpoints: urls, transport: transport, health: UniversalWalletEndpointHealth())
        let keys = ClusterKeyReadRecorder()
        let wallet = try Self.walletWithSolanaAccount(chainId: chain.chainId)
        let defaults = UserDefaults(suiteName: "solana-cluster-local-\(UUID().uuidString)")!
        let store = SolanaPendingBroadcastStore(userDefaults: defaults, logger: nil)
        let service = try SolanaTransferService(wallet: wallet, chain: chain,
            rpcClient: client, balanceSync: FakeSolanaTransferBalanceSync(nativeLamports: "2000000000"),
            mnemonicProvider: keys, pendingStore: store, providerRPCURL: nil, networkDefinition: [UniversalWalletRegistry.solanaMainnet.id, UniversalWalletRegistry.solanaDevnet.id].contains(network.id) ? nil : network)
        return ClusterFixture(chain: chain, service: service, client: client, transport: transport,
                              keys: keys, store: store, defaults: defaults, walletId: wallet.metaId)
    }

    private struct ClusterFixture {
        let chain: ChainModel
        let service: SolanaTransferService
        let client: SolanaFailoverRpcClient
        let transport: ClusterTransport
        let keys: ClusterKeyReadRecorder
        let store: SolanaPendingBroadcastStore
        let defaults: UserDefaults
        let walletId: String
    }

    private final class ClusterKeyReadRecorder: UniversalWalletMnemonicProviding {
        private(set) var reads = 0
        func mnemonic(for _: MetaAccountModel, chain _: ChainModel) throws -> String? {
            reads += 1
            return nil
        }
    }

    private final class ClusterTransport: UniversalWalletHTTPTransport {
        // Same exact public cluster identities as the independently qualified Android registry.
        static let mainnet = "5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d"
        static let devnet = "EtWTRABZaYq6iMfeYKouRu166VU2xqa1wcaWoxPkrZBG"
        static let custom = "https://a-custom.invalid/rpc"
        static let fallback = "https://b-fallback.invalid/rpc"
        var genesis: String
        var fallbackGenesis = ClusterTransport.mainnet
        var blockhashIsValid = false
        var fallbackBlockhashIsValid: Bool?
        var finalizedBlockhash: String? = SolanaSendServiceTests.blockhash
        var validitySlot: Int64 = 1_000
        var statusSlot: Int64 = 1_000
        var failExpiryRequests = false
        var signatureLanded = false
        var afterFee: (() -> Void)?
        var afterBlock: (() -> Void)?
        let wrongQuote: Bool
        private(set) var requests: [(String, String)] = []
        private(set) var rpcBodies: [[String: Any]] = []
        var methods: [String] { requests.map { $0.1 } }
        var urls: [String] { requests.map { $0.0 } }

        init(genesis: String, wrongQuote: Bool) { self.genesis = genesis; self.wrongQuote = wrongQuote }

        func perform(_ request: URLRequest) async throws -> Data {
            let body = try XCTUnwrap(request.httpBody)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let method = try XCTUnwrap(json["method"] as? String)
            let url = try XCTUnwrap(request.url?.absoluteString)
            requests.append((url, method))
            rpcBodies.append(json)
            let result: Any
            switch method {
            case "getGenesisHash": result = url == Self.fallback ? fallbackGenesis : genesis
            case "getAccountInfo": result = ["context": ["slot": 1], "value": NSNull()] as [String: Any]
            case "getRecentPrioritizationFees": result = [] as [Int]
            case "getLatestBlockhash": result = ["context": ["slot": 1], "value": ["blockhash": SolanaSendServiceTests.blockhash, "lastValidBlockHeight": 99]] as [String: Any]
            case "getFeeForMessage":
                result = ["context": ["slot": 1], "value": wrongQuote && url == Self.custom ? 777 : 5_000] as [String: Any]
                afterFee?()
            case "getBalance": result = ["context": ["slot": 1], "value": 2_000_000_000] as [String: Any]
            case "getTokenAccountsByOwner": result = ["context": ["slot": 1], "value": []] as [String: Any]
            case "isBlockhashValid":
                if failExpiryRequests { throw URLError(.notConnectedToInternet) }
                result = ["context": ["slot": validitySlot], "value": url == Self.fallback ? (fallbackBlockhashIsValid ?? blockhashIsValid) : blockhashIsValid] as [String: Any]
            case "getBlock":
                if failExpiryRequests { throw URLError(.notConnectedToInternet) }
                if let hash = finalizedBlockhash {
                    result = ["blockhash": hash, "blockHeight": 80, "parentSlot": 99, "previousBlockhash": SolanaSendServiceTests.recipient] as [String: Any]
                } else { result = NSNull() }
                afterBlock?()

            case "getBlockHeight": result = 1000
            case "getSignatureStatuses":
                let status: Any = signatureLanded ? ["slot": 101, "confirmations": NSNull(), "err": NSNull(), "confirmationStatus": "finalized"] as [String: Any] : NSNull()
                result = ["context": ["slot": statusSlot], "value": [status]] as [String: Any]
            case "sendTransaction": throw URLError(.networkConnectionLost) // Recorder only, never a network writer.
            default: throw URLError(.unsupportedURL)
            }
            return try JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "id": try XCTUnwrap(json["id"]), "result": result])
        }
    }
}

// Actual production store/client/broadcaster/service with local public wire fixtures only.
extension SolanaSendServiceTests {
    func testAdmissionStoreRejectsReplacingReadableValidPendingRecord() throws {
        let f = try admissionFixture()
        let first = try semanticPublicRecord(scope: f.scope, amount: 1)
        let second = try semanticPublicRecord(scope: f.scope, amount: 2)
        try f.store.save(first, for: f.scope)
        let original = f.defaults.data(forKey: SolanaPendingBroadcastStore.key(for: f.scope))
        XCTAssertThrowsError(try f.store.save(second, for: f.scope))
        XCTAssertEqual(f.defaults.data(forKey: SolanaPendingBroadcastStore.key(for: f.scope)), original)
        XCTAssertEqual(f.store.pending(for: f.scope), first)
    }

    func testAdmissionRecreatedStoreCannotReplaceAnotherInstancePendingRecord() throws {
        let f = try admissionFixture()
        let first = try semanticPublicRecord(scope: f.scope, amount: 1)
        let second = try semanticPublicRecord(scope: f.scope, amount: 2)
        try f.store.save(first, for: f.scope)
        let reopened = SolanaPendingBroadcastStore(userDefaults: UserDefaults(suiteName: f.suite)!, logger: nil)
        XCTAssertEqual(reopened.pending(for: f.scope), first)
        XCTAssertThrowsError(try reopened.save(second, for: f.scope))
        XCTAssertEqual(f.store.pending(for: f.scope), first)
    }

    func testAdmissionDirectBroadcastPreservesExistingValidPaymentWithoutOutput() async throws {
        let f = try admissionFixture()
        let first = try semanticPublicRecord(scope: f.scope, amount: 1)
        try f.store.save(first, for: f.scope)
        let bytes = f.defaults.data(forKey: SolanaPendingBroadcastStore.key(for: f.scope))
        let signed = try admissionSigned(amount: 2)
        f.transport.signatures[signed.signedTransactionBase64] = signed.signatureBase58
        _ = try? await f.broadcaster.broadcast(signed, lastValidBlockHeight: 99, scope: f.scope,
            options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(f.transport.sent, [])
        XCTAssertEqual(f.defaults.data(forKey: SolanaPendingBroadcastStore.key(for: f.scope)), bytes)
    }

    func testAdmissionDirectBroadcastPreservesUnboundOriginalPaymentWithoutOutput() async throws {
        let f = try admissionFixture()
        try f.store.save(legacyClusterRecord(scope: f.scope), for: f.scope)
        let bytes = f.defaults.data(forKey: SolanaPendingBroadcastStore.key(for: f.scope))
        let signed = try admissionSigned(amount: 2)
        f.transport.signatures[signed.signedTransactionBase64] = signed.signatureBase58
        _ = try? await f.broadcaster.broadcast(signed, lastValidBlockHeight: 99, scope: f.scope,
            options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(f.transport.sent, [])
        XCTAssertEqual(f.defaults.data(forKey: SolanaPendingBroadcastStore.key(for: f.scope)), bytes)
    }

    func testAdmissionTwoBroadcastersCannotOutputDifferentPaymentsForOneScope() async throws {
        let f = try admissionFixture()
        let first = try admissionSigned(amount: 1)
        let second = try admissionSigned(amount: 2)
        f.transport.signatures = [first.signedTransactionBase64: first.signatureBase58,
                                  second.signedTransactionBase64: second.signatureBase58]
        let entered = expectation(description: "first output held")
        let gate = AdmissionGate()
        f.transport.beforeSend = { wire in
            if wire == first.signedTransactionBase64 { entered.fulfill(); await gate.wait() }
        }
        let task = Task { try await f.broadcaster.broadcast(first, lastValidBlockHeight: 99,
            scope: f.scope, options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom) }
        await fulfillment(of: [entered], timeout: 5)
        let other = SolanaTransactionBroadcaster(rpcClient: f.client, expectedPayer: Self.sender,
            store: SolanaPendingBroadcastStore(userDefaults: UserDefaults(suiteName: f.suite)!, logger: nil),
            policy: .init(timeout: 0, pollInterval: 0))
        _ = try? await other.broadcast(second, lastValidBlockHeight: 99, scope: f.scope,
            options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        await gate.open()
        _ = await task.result
        XCTAssertEqual(f.transport.sent, [first.signedTransactionBase64])
        XCTAssertEqual(f.store.pending(for: f.scope)?.signature, first.signatureBase58)
    }

    func testAdmissionLateAcknowledgementCannotOverwriteChangedDurableRecord() async throws {
        let f = try admissionFixture()
        let first = try admissionSigned(amount: 1)
        f.transport.signatures[first.signedTransactionBase64] = first.signatureBase58
        let entered = expectation(description: "output held")
        let gate = AdmissionGate()
        f.transport.beforeSend = { _ in entered.fulfill(); await gate.wait() }
        let task = Task { try await f.broadcaster.broadcast(first, lastValidBlockHeight: 99,
            scope: f.scope, options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom) }
        await fulfillment(of: [entered], timeout: 5)
        let replacement = try semanticPublicRecord(scope: f.scope, amount: 2)
        let bytes = try semanticEncodedRecord(replacement)
        // Novel external preference mutation is retained as unreadable conflict with journal authority.
        f.defaults.set(bytes, forKey: SolanaPendingBroadcastStore.key(for: f.scope))
        XCTAssertEqual(f.store.readState(for: f.scope), .unreadable)
        await gate.open()
        _ = await task.result
        XCTAssertEqual(f.defaults.data(forKey: SolanaPendingBroadcastStore.key(for: f.scope)), bytes)
        XCTAssertEqual(f.store.readState(for: f.scope), .unreadable)
    }

    func testAdmissionLateResolutionCannotGrantServiceKeyAccessOverNewPendingRecord() async throws {
        let f = try admissionFixture()
        let first = try admissionReportedRecord(scope: f.scope)
        try f.store.save(first, for: f.scope)
        f.transport.base.signatureLanded = true
        let entered = expectation(description: "recovery status held")
        let gate = AdmissionGate()
        f.transport.beforeStatus = { entered.fulfill(); await gate.wait() }
        let task = Task { try await f.service.submit(transfer: Self.nativeTransfer(chain: f.chain)) }
        await fulfillment(of: [entered], timeout: 5)
        let replacement = try semanticPublicRecord(scope: f.scope, amount: 2)
        let bytes = try semanticEncodedRecord(replacement)
        f.defaults.set(bytes, forKey: SolanaPendingBroadcastStore.key(for: f.scope))
        XCTAssertEqual(f.store.readState(for: f.scope), .unreadable)
        await gate.open()
        _ = await task.result
        XCTAssertEqual(f.keys.reads, 0, "Old resolution cannot authorize keys over a new unresolved payment")
        XCTAssertEqual(f.defaults.data(forKey: SolanaPendingBroadcastStore.key(for: f.scope)), bytes)
        XCTAssertEqual(f.transport.sent, [])
    }

    func testAdmissionLateResolutionCannotClearChangedRecordWithSameSignature() async throws {
        let f = try admissionFixture()
        let first = try admissionReportedRecord(scope: f.scope)
        try f.store.save(first, for: f.scope)
        f.transport.base.signatureLanded = true
        let entered = expectation(description: "recovery status held")
        let gate = AdmissionGate()
        f.transport.beforeStatus = { entered.fulfill(); await gate.wait() }
        let task = Task { await f.broadcaster.priorTransferState(scope: f.scope, rpcURL: ClusterTransport.custom) }
        await fulfillment(of: [entered], timeout: 5)
        let bytes = try semanticEncodedRecord(first, changes: ["createdAt": 1_760_000_005_000, "reportedAsSent": false])
        f.defaults.set(bytes, forKey: SolanaPendingBroadcastStore.key(for: f.scope))
        XCTAssertEqual(f.store.readState(for: f.scope), .unreadable)
        await gate.open()
        let result = await task.value
        XCTAssertNotEqual(result, .clear)
        XCTAssertEqual(f.defaults.data(forKey: SolanaPendingBroadcastStore.key(for: f.scope)), bytes)
    }

    func testAdmissionHealthyEmptyScopeRetainsAcceptedExactPayment() async throws {
        let f = try admissionFixture()
        let signed = try admissionSigned(amount: 1)
        f.transport.signatures[signed.signedTransactionBase64] = signed.signatureBase58
        let result = try await f.broadcaster.broadcast(signed, lastValidBlockHeight: 99, scope: f.scope,
            options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(result, .sent(signature: signed.signatureBase58, confirmed: false))
        XCTAssertEqual(f.transport.sent, [signed.signedTransactionBase64])
        XCTAssertEqual(f.store.pending(for: f.scope)?.transactionBase64, signed.signedTransactionBase64)
        XCTAssertEqual(f.store.pending(for: f.scope)?.reportedAsSent, true)
    }

    func testAdmissionOtherWalletRemainsAvailableDuringHeldOutput() async throws {
        let f = try admissionFixture()
        let first = try admissionSigned(amount: 1)
        let second = try admissionSigned(amount: 2)
        f.transport.signatures = [first.signedTransactionBase64: first.signatureBase58,
                                  second.signedTransactionBase64: second.signatureBase58]
        let entered = expectation(description: "first wallet output held")
        let gate = AdmissionGate()
        f.transport.beforeSend = { wire in
            if wire == first.signedTransactionBase64 { entered.fulfill(); await gate.wait() }
        }
        let task = Task { try await f.broadcaster.broadcast(first, lastValidBlockHeight: 99,
            scope: f.scope, options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom) }
        await fulfillment(of: [entered], timeout: 5)
        let otherScope = SolanaPendingBroadcastScope(walletId: f.scope.walletId + "-other", chainId: f.scope.chainId)
        let result = try await f.broadcaster.broadcast(second, lastValidBlockHeight: 99, scope: otherScope,
            options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(result, .sent(signature: second.signatureBase58, confirmed: false))
        XCTAssertEqual(f.store.pending(for: otherScope)?.signature, second.signatureBase58)
        let balance = try await f.client.balance(address: Self.sender, commitment: .confirmed, rpcURL: ClusterTransport.custom)
        XCTAssertEqual(balance, 2_000_000_000)
        await gate.open()
        _ = await task.result
        XCTAssertEqual(f.transport.sent.count, 2)
    }

    private func admissionSigned(amount: Int64) throws -> SignedSolanaTransaction {
        let unsigned = try SolanaTransferTransactionBuilder.buildNativeTransfer(senderAddress: Self.sender,
            recipientAddress: Self.recipient, lamports: amount, recentBlockhash: Self.blockhash)
        return try SolanaTransactionSigner.signSerializedTransaction(mnemonic: Self.mnemonic,
            transactionBase64: unsigned.transactionBase64, expectedSigner: Self.sender)
    }

    private func admissionReportedRecord(scope: SolanaPendingBroadcastScope) throws -> SolanaPendingBroadcast {
        var record = try semanticPublicRecord(scope: scope, amount: 1)
        record.reportedAsSent = true
        return record
    }

    private func admissionFixture() throws -> AdmissionFixture {
        let suite = "solana-pending-admission-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = SolanaPendingBroadcastStore(userDefaults: defaults, logger: nil)
        let transport = AdmissionTransport()
        let client = try SolanaRpcClient(transport: transport, defaultRPCURL: ClusterTransport.custom)
        let chain = Self.solanaChain(nodes: [ChainNodeModel(url: URL(string: ClusterTransport.custom)!, name: "Local fixture", apikey: nil)])
        let wallet = try Self.walletWithSolanaAccount(chainId: chain.chainId)
        let keys = ClusterKeyReadRecorder()
        let service = try SolanaTransferService(wallet: wallet, chain: chain, rpcClient: client,
            balanceSync: FakeSolanaTransferBalanceSync(nativeLamports: "2000000000"), mnemonicProvider: keys,
            pendingStore: store, confirmationPolicy: .init(timeout: 0, pollInterval: 0), providerRPCURL: nil)
        return AdmissionFixture(suite: suite, defaults: defaults, store: store, transport: transport, client: client,
            chain: chain, keys: keys, service: service,
            scope: SolanaPendingBroadcastScope(walletId: wallet.metaId, chainId: chain.chainId),
            broadcaster: SolanaTransactionBroadcaster(rpcClient: client, expectedPayer: Self.sender,
                store: store, policy: .init(timeout: 0, pollInterval: 0)))
    }

    private struct AdmissionFixture {
        let suite: String
        let defaults: UserDefaults
        let store: SolanaPendingBroadcastStore
        let transport: AdmissionTransport
        let client: SolanaRpcClient
        let chain: ChainModel
        let keys: ClusterKeyReadRecorder
        let service: SolanaTransferService
        let scope: SolanaPendingBroadcastScope
        let broadcaster: SolanaTransactionBroadcaster
    }

    private actor AdmissionGate {
        private var opened = false
        private var waiting: [CheckedContinuation<Void, Never>] = []
        func wait() async {
            if opened { return }
            await withCheckedContinuation { waiting.append($0) }
        }
        func open() {
            opened = true
            waiting.forEach { $0.resume() }
            waiting.removeAll()
        }
    }

    private final class AdmissionTransport: UniversalWalletHTTPTransport {
        let base = ClusterTransport(genesis: ClusterTransport.mainnet, wrongQuote: false)
        var signatures: [String: String] = [:]
        var beforeSend: ((String) async -> Void)?
        var beforeStatus: (() async -> Void)?
        var beforeGenesis: (() async -> Void)?
        private(set) var sent: [String] = []
        func perform(_ request: URLRequest) async throws -> Data {
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
            let method = try XCTUnwrap(json["method"] as? String)
            if method == "getSignatureStatuses" { await beforeStatus?() }
            if method == "getGenesisHash" { await beforeGenesis?() }
            guard method == "sendTransaction" else { return try await base.perform(request) }
            let wire = try XCTUnwrap((json["params"] as? [Any])?.first as? String)
            sent.append(wire)
            await beforeSend?(wire)
            return try JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "id": XCTUnwrap(json["id"]),
                "result": XCTUnwrap(signatures[wire])])
        }
    }
}

extension SolanaSendServiceTests {
    func testAdmissionSnapshotRejectsSameModelWithChangedUnknownBytes() throws {
        let f = try admissionFixture()
        let record = try semanticPublicRecord(scope: f.scope, amount: 1)
        try f.store.save(record, for: f.scope)
        let original = try XCTUnwrap(f.store.snapshot(for: f.scope))
        let bytes = try semanticEncodedRecord(record, changes: ["futureOwner": "new-publication"])
        f.defaults.set(bytes, forKey: SolanaPendingBroadcastStore.key(for: f.scope))
        XCTAssertEqual(f.store.readState(for: f.scope), .unreadable)
        XCTAssertFalse(f.store.clear(original, for: f.scope))
        XCTAssertThrowsError(try f.store.markReported(original, for: f.scope)) {
            XCTAssertEqual($0 as? SolanaPendingBroadcastStoreError, .unreadableRecord)
        }
        XCTAssertEqual(f.defaults.data(forKey: SolanaPendingBroadcastStore.key(for: f.scope)), bytes)
    }

    func testAdmissionSnapshotAcknowledgementPreservesUnknownFields() throws {
        let f = try admissionFixture()
        let record = try semanticPublicRecord(scope: f.scope, amount: 1)
        let bytes = try semanticEncodedRecord(record, changes: ["futureOwner": "preserved"])
        f.defaults.set(bytes, forKey: SolanaPendingBroadcastStore.key(for: f.scope))
        let snapshot = try XCTUnwrap(f.store.snapshot(for: f.scope))
        XCTAssertTrue(try f.store.markReported(snapshot, for: f.scope))
        let data = try XCTUnwrap(f.defaults.data(forKey: SolanaPendingBroadcastStore.key(for: f.scope)))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["futureOwner"] as? String, "preserved")
        XCTAssertEqual(object["reportedAsSent"] as? Bool, true)
        XCTAssertEqual(f.store.pending(for: f.scope)?.transactionBase64, record.transactionBase64)
    }

    func testAdmissionLateSnapshotCannotResurrectRemovedPayment() throws {
        let f = try admissionFixture()
        let snapshot = try f.store.admit(semanticPublicRecord(scope: f.scope, amount: 1), for: f.scope)
        XCTAssertTrue(f.store.clear(snapshot, for: f.scope))
        XCTAssertFalse(try f.store.markReported(snapshot, for: f.scope))
        XCTAssertFalse(f.store.clear(snapshot, for: f.scope))
        XCTAssertEqual(f.store.readState(for: f.scope), .absent)
    }

    func testAdmissionRegistryTokenRejectsOverlappingAndStaleOwners() throws {
        let registry = SolanaSubmissionRegistry()
        let a = SolanaPendingBroadcastScope(walletId: "one", chainId: "solana")
        let b = SolanaPendingBroadcastScope(walletId: "two", chainId: "solana")
        let first = try XCTUnwrap(registry.begin(a))
        XCTAssertNil(registry.begin(a))
        let other = try XCTUnwrap(registry.begin(b))
        XCTAssertFalse(registry.owns(first, scope: b))
        registry.end(first)
        let replacement = try XCTUnwrap(registry.begin(a))
        registry.end(first)
        XCTAssertTrue(registry.owns(replacement, scope: a))
        XCTAssertNil(registry.begin(a))
        registry.end(replacement); registry.end(other)
        XCTAssertNotNil(registry.begin(a))
    }

    func testAdmissionHeldOutputBlocksDirectRetryAndRecovery() async throws {
        let f = try admissionFixture()
        let signed = try admissionSigned(amount: 1)
        f.transport.signatures[signed.signedTransactionBase64] = signed.signatureBase58
        let entered = expectation(description: "output held")
        let gate = AdmissionGate()
        f.transport.beforeSend = { _ in entered.fulfill(); await gate.wait() }
        let task = Task { try await f.broadcaster.broadcast(signed, lastValidBlockHeight: 99,
            scope: f.scope, options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom) }
        await fulfillment(of: [entered], timeout: 5)
        let retry = await f.broadcaster.retry(signature: signed.signatureBase58, scope: f.scope,
            options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertNil(retry)
        let recovery = await f.broadcaster.priorTransferState(scope: f.scope, rpcURL: ClusterTransport.custom)
        XCTAssertEqual(recovery, .inProgress)
        XCTAssertEqual(f.transport.sent, [signed.signedTransactionBase64])
        await gate.open(); _ = await task.result
        XCTAssertEqual(f.store.pending(for: f.scope)?.signature, signed.signatureBase58)
    }

    func testAdmissionServiceRechecksRetainedAuthorityAfterClusterAwait() async throws {
        let f = try admissionFixture()
        let entered = expectation(description: "cluster check held")
        let gate = AdmissionGate()
        f.transport.beforeGenesis = { entered.fulfill(); await gate.wait() }
        let task = Task { try await f.service.submit(transfer: Self.nativeTransfer(chain: f.chain)) }
        await fulfillment(of: [entered], timeout: 5)
        let pending = try semanticPublicRecord(scope: f.scope, amount: 2)
        try f.store.save(pending, for: f.scope)
        let bytes = f.defaults.data(forKey: SolanaPendingBroadcastStore.key(for: f.scope))
        await gate.open(); _ = await task.result
        XCTAssertEqual(f.keys.reads, 0)
        XCTAssertEqual(f.transport.sent, [])
        XCTAssertEqual(f.defaults.data(forKey: SolanaPendingBroadcastStore.key(for: f.scope)), bytes)
    }
}

extension SolanaSendServiceTests {
    func testAdmissionFailedRemovalReadbackRetainsAuthority() throws {
        let f = try admissionFixture()
        let suite = "solana-remove-readback-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(AdmissionFailingDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SolanaPendingBroadcastStore(userDefaults: defaults, logger: nil)
        let record = try semanticPublicRecord(scope: f.scope, amount: 1)
        let snapshot = try store.admit(record, for: f.scope)
        defaults.allowRemoval = false
        XCTAssertFalse(store.clear(snapshot, for: f.scope))
        XCTAssertEqual(store.readState(for: f.scope), .pending(record))
    }

    func testAdmissionFailedInsertReadbackCannotReachOutput() async throws {
        let f = try admissionFixture()
        let suite = "solana-insert-readback-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(AdmissionFailingDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.allowWrites = false
        let store = SolanaPendingBroadcastStore(userDefaults: defaults, logger: nil)
        let broadcaster = SolanaTransactionBroadcaster(rpcClient: f.client, expectedPayer: Self.sender,
            store: store, policy: .init(timeout: 0, pollInterval: 0))
        do {
            _ = try await broadcaster.broadcast(admissionSigned(amount: 1), lastValidBlockHeight: 99,
                scope: f.scope, options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
            XCTFail("Unacknowledged retention cannot authorize output")
        } catch { XCTAssertEqual(error as? SolanaPendingBroadcastStoreError, .notPersisted) }
        XCTAssertEqual(f.transport.sent, [])
        XCTAssertEqual(store.readState(for: f.scope), .absent)
    }

    func testAdmissionLegacyStoreCannotClaimAtomicSnapshotSupport() throws {
        let f = try admissionFixture()
        let record = try semanticPublicRecord(scope: f.scope, amount: 1)
        let snapshot = try f.store.admit(record, for: f.scope)
        let legacy = AdmissionUnsupportedStore()
        XCTAssertNil(try legacy.snapshot(for: f.scope))
        XCTAssertThrowsError(try legacy.admit(record, for: f.scope))
        XCTAssertFalse(try legacy.markReported(snapshot, for: f.scope))
        XCTAssertFalse(legacy.clear(snapshot, for: f.scope))
        legacy.record = record
        XCTAssertThrowsError(try legacy.snapshot(for: f.scope))
        XCTAssertEqual(legacy.pending(for: f.scope), record)
    }

    private final class AdmissionFailingDefaults: UserDefaults {
        var allowWrites = true
        var allowRemoval = true
        override func set(_ value: Any?, forKey defaultName: String) {
            if allowWrites { super.set(value, forKey: defaultName) }
        }
        override func removeObject(forKey defaultName: String) {
            if allowRemoval { super.removeObject(forKey: defaultName) }
        }
    }

    private final class AdmissionUnsupportedStore: SolanaPendingBroadcastStoring {
        var record: SolanaPendingBroadcast?
        func pending(for _: SolanaPendingBroadcastScope) -> SolanaPendingBroadcast? { record }
        func save(_: SolanaPendingBroadcast, for _: SolanaPendingBroadcastScope) throws {
            throw SolanaPendingBroadcastStoreError.notPersisted
        }
        func clear(signature _: String, for _: SolanaPendingBroadcastScope) {}
    }
}


// Durability baseline: actual store/broadcaster with deterministic preference-cache or
// mutation failure seams. Cache discard is not a simulator process/power-loss test.
extension SolanaSendServiceTests {
    func testDurabilityCacheReadbackCannotLoseAdmittedPaymentOnReopen() throws {
        let f = try durabilityFixture(cacheOnly: true)
        let record = try semanticPublicRecord(scope: f.scope)
        try f.store.save(record, for: f.scope)
        XCTAssertEqual(f.store.pending(for: f.scope), record, "The actual store sees its cached readback")
        let reopened = durabilityStore(defaults: try XCTUnwrap(UserDefaults(suiteName: f.suite)), directory: f.directory)
        XCTAssertEqual(reopened.pending(for: f.scope), record, "Admission must survive loss of the preference cache")
    }

    func testDurabilityAcknowledgedPaymentSurvivesPreferenceCacheLoss() async throws {
        let f = try durabilityFixture(cacheOnly: true)
        let signed = try admissionSigned(amount: 1)
        f.transport.signatures[signed.signedTransactionBase64] = signed.signatureBase58
        let result = try await f.broadcaster.broadcast(signed, lastValidBlockHeight: 99, scope: f.scope,
            options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(result, .sent(signature: signed.signatureBase58, confirmed: false))
        XCTAssertEqual(f.transport.sent, [signed.signedTransactionBase64])
        let reopened = durabilityStore(defaults: try XCTUnwrap(UserDefaults(suiteName: f.suite)), directory: f.directory)
        XCTAssertEqual(reopened.pending(for: f.scope)?.transactionBase64, signed.signedTransactionBase64)
        XCTAssertEqual(reopened.pending(for: f.scope)?.reportedAsSent, true)
    }

    func testDurabilityFailedAcknowledgementUpdateDoesNotReturnNormalSent() async throws {
        let f = try durabilityFixture()
        let signed = try admissionSigned(amount: 1)
        f.transport.signatures[signed.signedTransactionBase64] = signed.signatureBase58
        f.transport.beforeSend = { _ in f.defaults.allowWrites = false }
        let result = try await f.broadcaster.broadcast(signed, lastValidBlockHeight: 99, scope: f.scope,
            options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(result, .unknown(signature: signed.signatureBase58))
        XCTAssertEqual(f.store.pending(for: f.scope)?.reportedAsSent, false)
        XCTAssertEqual(f.transport.sent, [signed.signedTransactionBase64])
    }

    func testDurabilityFailedConfirmedRemovalDoesNotReturnNormalCompletion() async throws {
        let f = try durabilityFixture()
        let signed = try admissionSigned(amount: 1)
        f.transport.signatures[signed.signedTransactionBase64] = signed.signatureBase58
        f.transport.base.signatureLanded = true
        f.defaults.allowRemoval = false
        let result = try await f.broadcaster.broadcast(signed, lastValidBlockHeight: 99, scope: f.scope,
            options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(result, .unknown(signature: signed.signatureBase58))
        XCTAssertEqual(f.store.pending(for: f.scope)?.transactionBase64, signed.signedTransactionBase64)
        XCTAssertEqual(f.transport.sent, [signed.signedTransactionBase64])
    }

    func testDurabilityFailedExpiryRemovalDoesNotReturnNormalCompletion() async throws {
        let f = try durabilityFixture()
        let signed = try admissionSigned(amount: 1)
        f.transport.signatures[signed.signedTransactionBase64] = signed.signatureBase58
        f.defaults.allowRemoval = false
        let result = try await f.broadcaster.broadcast(signed, lastValidBlockHeight: 99, blockhashContextSlot: 100, scope: f.scope,
            options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(result, .unknown(signature: signed.signatureBase58))
        XCTAssertEqual(f.store.pending(for: f.scope)?.transactionBase64, signed.signedTransactionBase64)
        XCTAssertTrue(f.transport.base.methods.contains("getBlock"), "Actual independently contextual expiry path executed")
    }

    func testDurabilityHealthyAcknowledgementRetainsExactPayment() async throws {
        let f = try durabilityFixture()
        let signed = try admissionSigned(amount: 1)
        f.transport.signatures[signed.signedTransactionBase64] = signed.signatureBase58
        let result = try await f.broadcaster.broadcast(signed, lastValidBlockHeight: 99, scope: f.scope,
            options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(result, .sent(signature: signed.signatureBase58, confirmed: false))
        XCTAssertEqual(f.store.pending(for: f.scope)?.transactionBase64, signed.signedTransactionBase64)
        XCTAssertEqual(f.store.pending(for: f.scope)?.reportedAsSent, true)
    }

    func testDurabilityHealthyConfirmedPaymentClearsExactRecord() async throws {
        let f = try durabilityFixture()
        let signed = try admissionSigned(amount: 1)
        f.transport.signatures[signed.signedTransactionBase64] = signed.signatureBase58
        f.transport.base.signatureLanded = true
        let result = try await f.broadcaster.broadcast(signed, lastValidBlockHeight: 99, scope: f.scope,
            options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(result, .sent(signature: signed.signatureBase58, confirmed: true))
        XCTAssertEqual(f.store.readState(for: f.scope), .absent)
        XCTAssertEqual(f.transport.sent.count, 1)
    }

    func testDurabilityUnboundLegacyBytesRemainAuthoritative() async throws {
        let f = try durabilityFixture()
        let bytes = try semanticEncodedRecord(legacyClusterRecord(scope: f.scope), changes: ["futureField": "retained"])
        let key = SolanaPendingBroadcastStore.key(for: f.scope)
        f.defaults.set(bytes, forKey: key)
        let signed = try admissionSigned(amount: 2)
        _ = try? await f.broadcaster.broadcast(signed, lastValidBlockHeight: 99, scope: f.scope,
            options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(f.defaults.data(forKey: key), bytes)
        XCTAssertEqual(f.transport.sent, [])
        let reopened = durabilityStore(defaults: try XCTUnwrap(UserDefaults(suiteName: f.suite)), directory: f.directory)
        XCTAssertEqual(reopened.pending(for: f.scope)?.transactionBase64, Self.legacyClusterSigned.signedTransactionBase64)
    }

    private func durabilityStore(defaults: UserDefaults, directory: URL) -> SolanaPendingBroadcastStore {
        SolanaPendingBroadcastStore(userDefaults: defaults, logger: nil,
            journal: try! SolanaPendingBroadcastJournal(parentDirectoryURL: directory))
    }

    private func durabilityFixture(cacheOnly: Bool = false) throws -> DurabilityFixture {
        let suite = "solana-durability-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(DurabilityDefaults(suiteName: suite))
        defaults.cacheOnly = cacheOnly
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700])
        let store = durabilityStore(defaults: defaults, directory: directory)
        let transport = AdmissionTransport()
        let client = try SolanaRpcClient(transport: transport, defaultRPCURL: ClusterTransport.custom)
        let scope = SolanaPendingBroadcastScope(walletId: suite, chainId: "solana")
        return DurabilityFixture(suite: suite, directory: directory, defaults: defaults, store: store,
            transport: transport, scope: scope, broadcaster: SolanaTransactionBroadcaster(rpcClient: client,
                expectedPayer: Self.sender, store: store, policy: .init(timeout: 0, pollInterval: 0)))
    }

    private struct DurabilityFixture {
        let suite: String
        let directory: URL
        let defaults: DurabilityDefaults
        let store: SolanaPendingBroadcastStore
        let transport: AdmissionTransport
        let scope: SolanaPendingBroadcastScope
        let broadcaster: SolanaTransactionBroadcaster
    }

    // A deterministic cache-only preference writer: same-process reads succeed while a
    // separate wrapper sees the unchanged backing domain. No disk failure is inferred.
    private final class DurabilityDefaults: UserDefaults {
        var cacheOnly = false
        var allowWrites = true
        var allowRemoval = true
        private var cache: [String: Any] = [:]
        override func object(forKey key: String) -> Any? { cache[key] ?? super.object(forKey: key) }
        override func data(forKey key: String) -> Data? { object(forKey: key) as? Data }
        override func set(_ value: Any?, forKey key: String) {
            guard allowWrites else { return }
            if cacheOnly { cache[key] = value } else { super.set(value, forKey: key) }
        }
        override func removeObject(forKey key: String) {
            guard allowRemoval else { return }
            cache.removeValue(forKey: key)
            super.removeObject(forKey: key)
        }
    }
}


extension SolanaSendServiceTests {
    func testDurabilityJournalParentAcknowledgementFailureIsUnavailable() throws {
        let f = try durabilityFixture()
        XCTAssertThrowsError(try SolanaPendingBroadcastJournal(parentDirectoryURL: f.directory, parentSync: { _ in -1 }))
        XCTAssertEqual(f.store.readState(for: f.scope), .absent)
    }

    func testDurabilityPartialWriteFailurePreservesExactPrefixAndBlocksOutput() async throws {
        let f = try durabilityFixture(cacheOnly: true)
        var calls = 0
        var prefix = Data()
        let journal = try SolanaPendingBroadcastJournal(parentDirectoryURL: f.directory,
            writeBytes: { fd, bytes, count in
                calls += 1
                guard calls == 1 else { errno = EIO; return -1 }
                let written = Darwin.write(fd, bytes, max(1, count / 2))
                if written > 0, let bytes { prefix = Data(bytes: bytes, count: written) }
                return written
            })
        let store = SolanaPendingBroadcastStore(userDefaults: f.defaults, logger: nil, journal: journal)
        let broadcaster = try durabilityBroadcaster(f, store: store)
        do {
            _ = try await broadcaster.broadcast(admissionSigned(amount: 1), lastValidBlockHeight: 99,
                scope: f.scope, options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
            XCTFail("An incomplete journal must never reach output")
        } catch { XCTAssertEqual(error as? SolanaPendingBroadcastStoreError, .notPersisted) }
        XCTAssertEqual(calls, 2)
        XCTAssertFalse(prefix.isEmpty)
        XCTAssertNotEqual(prefix.last, 0x0A)
        let file = try durabilityJournalFile(f)
        XCTAssertEqual(try Data(contentsOf: file), prefix)
        let reopened = durabilityStore(defaults: try XCTUnwrap(UserDefaults(suiteName: f.suite)), directory: f.directory)
        XCTAssertEqual(reopened.readState(for: f.scope), .unreadable)
        XCTAssertThrowsError(try reopened.admit(semanticPublicRecord(scope: f.scope, amount: 2), for: f.scope))
        XCTAssertEqual(try Data(contentsOf: file), prefix)
        XCTAssertEqual(f.transport.sent, [])
        let other = SolanaPendingBroadcastScope(walletId: f.scope.walletId + "-other", chainId: f.scope.chainId)
        XCTAssertEqual(reopened.readState(for: other), .absent)
        let record = try semanticPublicRecord(scope: other)
        _ = try reopened.admit(record, for: other)
        XCTAssertEqual(reopened.readState(for: other), .pending(record))
    }

    func testDurabilityShortWritesCompleteBeforeAcknowledgement() throws {
        let f = try durabilityFixture(cacheOnly: true)
        var calls = 0
        let journal = try SolanaPendingBroadcastJournal(parentDirectoryURL: f.directory,
            writeBytes: { fd, bytes, count in
                calls += 1
                return Darwin.write(fd, bytes, min(count, 17))
            })
        let store = SolanaPendingBroadcastStore(userDefaults: f.defaults, logger: nil, journal: journal)
        let record = try semanticPublicRecord(scope: f.scope)
        _ = try store.admit(record, for: f.scope)
        XCTAssertGreaterThan(calls, 1)
        let reopened = durabilityStore(defaults: try XCTUnwrap(UserDefaults(suiteName: f.suite)), directory: f.directory)
        XCTAssertEqual(reopened.readState(for: f.scope), .pending(record))
    }

    func testDurabilityJournalFileSyncFailureCannotReachOutput() async throws {
        try await assertDurabilityBarrierFailure(fileFailure: true)
    }

    func testDurabilityJournalDirectorySyncFailureCannotReachOutput() async throws {
        try await assertDurabilityBarrierFailure(fileFailure: false)
    }

    private func assertDurabilityBarrierFailure(fileFailure: Bool) async throws {
        let f = try durabilityFixture()
        let fault = DurabilityJournalFault()
        let journal = try SolanaPendingBroadcastJournal(parentDirectoryURL: f.directory,
            fileSync: { fd in fault.written && fileFailure ? -1 : Darwin.fsync(fd) },
            directorySync: { fd in fault.written && !fileFailure ? -1 : Darwin.fsync(fd) },
            boundaryHook: { boundary in if case .afterWrite = boundary { fault.written = true } })
        let store = SolanaPendingBroadcastStore(userDefaults: f.defaults, logger: nil, journal: journal)
        let broadcaster = try durabilityBroadcaster(f, store: store)
        let signed = try admissionSigned(amount: 1)
        do {
            _ = try await broadcaster.broadcast(signed, lastValidBlockHeight: 99, scope: f.scope,
                options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
            XCTFail("Unsynchronized retention cannot reach output")
        } catch { XCTAssertEqual(error as? SolanaPendingBroadcastStoreError, .notPersisted) }
        XCTAssertTrue(fault.written)
        XCTAssertEqual(f.transport.sent, [])
        XCTAssertEqual(store.readState(for: f.scope), .unreadable)
        let recovered = durabilityStore(defaults: f.defaults, directory: f.directory)
        XCTAssertEqual(recovered.pending(for: f.scope)?.transactionBase64, signed.signedTransactionBase64)
        XCTAssertThrowsError(try recovered.save(semanticPublicRecord(scope: f.scope, amount: 2), for: f.scope))
    }

    func testDurabilityCompleteUnacknowledgedWriteMustBeResynchronized() throws {
        let f = try durabilityFixture()
        let journal = try SolanaPendingBroadcastJournal(parentDirectoryURL: f.directory) { boundary in
            if case .afterWrite = boundary { throw SolanaPendingBroadcastStoreError.notPersisted }
        }
        let store = SolanaPendingBroadcastStore(userDefaults: f.defaults, logger: nil, journal: journal)
        let record = try semanticPublicRecord(scope: f.scope)
        XCTAssertThrowsError(try store.admit(record, for: f.scope))
        let failed = try SolanaPendingBroadcastJournal(parentDirectoryURL: f.directory, fileSync: { _ in -1 })
        let reopened = SolanaPendingBroadcastStore(userDefaults: f.defaults, logger: nil, journal: failed)
        XCTAssertEqual(reopened.readState(for: f.scope), .unreadable)
        XCTAssertThrowsError(try reopened.admit(record, for: f.scope))
        let acknowledged = durabilityStore(defaults: f.defaults, directory: f.directory)
        XCTAssertEqual(acknowledged.pending(for: f.scope), record)
    }

    func testDurabilityInterruptedClearRetainsAuthorityUntilBarrierRecovers() throws {
        let f = try durabilityFixture()
        let record = try semanticPublicRecord(scope: f.scope)
        let snapshot = try f.store.admit(record, for: f.scope)
        let fault = DurabilityJournalFault()
        let journal = try SolanaPendingBroadcastJournal(parentDirectoryURL: f.directory,
            fileSync: { fd in fault.written ? -1 : Darwin.fsync(fd) },
            boundaryHook: { boundary in if case .afterWrite = boundary { fault.written = true } })
        let store = SolanaPendingBroadcastStore(userDefaults: f.defaults, logger: nil, journal: journal)
        XCTAssertFalse(store.clear(snapshot, for: f.scope))
        XCTAssertEqual(store.readState(for: f.scope), .unreadable)
        XCTAssertThrowsError(try store.admit(semanticPublicRecord(scope: f.scope, amount: 2), for: f.scope))
        let recovered = durabilityStore(defaults: f.defaults, directory: f.directory)
        XCTAssertEqual(recovered.readState(for: f.scope), .absent, "Only successful replay synchronization acknowledges clear")
    }

    func testDurabilityInterruptedReportReturnsUnresolvedAndRecoversExactBytes() async throws {
        let f = try durabilityFixture()
        let fault = DurabilityJournalFault()
        let journal = try SolanaPendingBroadcastJournal(parentDirectoryURL: f.directory,
            fileSync: { fd in fault.failReport ? -1 : Darwin.fsync(fd) },
            boundaryHook: { boundary in
                if case .afterWrite = boundary { fault.writes += 1; fault.failReport = fault.writes == 2 }
            })
        let store = SolanaPendingBroadcastStore(userDefaults: f.defaults, logger: nil, journal: journal)
        let broadcaster = try durabilityBroadcaster(f, store: store)
        let signed = try admissionSigned(amount: 1)
        f.transport.signatures[signed.signedTransactionBase64] = signed.signatureBase58
        let outcome = try await broadcaster.broadcast(signed, lastValidBlockHeight: 99, scope: f.scope,
            options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(outcome, .unknown(signature: signed.signatureBase58))
        XCTAssertEqual(store.readState(for: f.scope), .unreadable)
        let recovered = durabilityStore(defaults: f.defaults, directory: f.directory)
        XCTAssertEqual(recovered.pending(for: f.scope)?.transactionBase64, signed.signedTransactionBase64)
        XCTAssertEqual(recovered.pending(for: f.scope)?.reportedAsSent, true)
        XCTAssertEqual(f.transport.sent, [signed.signedTransactionBase64])
    }

    func testDurabilityJournalRevisionRejectsSameBytesAfterClearAndReadmission() throws {
        let f = try durabilityFixture()
        let record = try semanticPublicRecord(scope: f.scope)
        let old = try f.store.admit(record, for: f.scope)
        XCTAssertTrue(f.store.clear(old, for: f.scope))
        let current = try f.store.admit(record, for: f.scope)
        XCTAssertFalse(f.store.clear(old, for: f.scope))
        XCTAssertFalse(try f.store.markReported(old, for: f.scope))
        XCTAssertEqual(f.store.pending(for: f.scope), record)
        XCTAssertTrue(f.store.clear(current, for: f.scope))
    }

    func testDurabilityTruncatedJournalPreservesBytesAndOtherWalletAccess() async throws {
        let f = try durabilityFixture()
        let record = try semanticPublicRecord(scope: f.scope)
        try f.store.save(record, for: f.scope)
        let file = try durabilityJournalFile(f)
        var corrupt = try Data(contentsOf: file); corrupt.append(Data("partial".utf8))
        try corrupt.write(to: file)
        XCTAssertEqual(f.store.readState(for: f.scope), .unreadable)
        _ = try? await f.broadcaster.broadcast(admissionSigned(amount: 2), lastValidBlockHeight: 99,
            scope: f.scope, options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(f.transport.sent, [])
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
        let other = SolanaPendingBroadcastScope(walletId: f.scope.walletId + "-other", chainId: f.scope.chainId)
        let signed = try admissionSigned(amount: 3)
        f.transport.signatures[signed.signedTransactionBase64] = signed.signatureBase58
        let result = try await f.broadcaster.broadcast(signed, lastValidBlockHeight: 99, scope: other,
            options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(result, .sent(signature: signed.signatureBase58, confirmed: false))
        let client = try SolanaRpcClient(transport: f.transport, defaultRPCURL: ClusterTransport.custom)
        let balance = try await client.balance(address: Self.sender, commitment: .confirmed, rpcURL: ClusterTransport.custom)
        XCTAssertEqual(balance, 2_000_000_000)
    }

    func testDurabilityPreferenceRemovalCannotEraseJournalHeldPayment() throws {
        let f = try durabilityFixture()
        let record = try semanticPublicRecord(scope: f.scope)
        try f.store.save(record, for: f.scope)
        f.defaults.removeObject(forKey: SolanaPendingBroadcastStore.key(for: f.scope))
        let reopened = durabilityStore(defaults: f.defaults, directory: f.directory)
        XCTAssertEqual(reopened.pending(for: f.scope), record)
        XCTAssertThrowsError(try reopened.save(semanticPublicRecord(scope: f.scope, amount: 2), for: f.scope))
    }

    func testDurabilityLegacyUnknownFieldsSurviveCacheLossAfterMigration() throws {
        let f = try durabilityFixture()
        let record = legacyClusterRecord(scope: f.scope)
        let bytes = try semanticEncodedRecord(record, changes: ["futureField": ["exact", "public"]])
        let key = SolanaPendingBroadcastStore.key(for: f.scope)
        f.defaults.set(bytes, forKey: key)
        XCTAssertNotNil(try f.store.snapshot(for: f.scope))
        f.defaults.removeObject(forKey: key)
        let reopened = durabilityStore(defaults: f.defaults, directory: f.directory)
        let snapshot = try XCTUnwrap(reopened.snapshot(for: f.scope))
        XCTAssertTrue(try reopened.markReported(snapshot, for: f.scope))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(f.defaults.data(forKey: key))) as? [String: Any])
        XCTAssertEqual(object["futureField"] as? [String], ["exact", "public"])
        XCTAssertNil(reopened.pending(for: f.scope)?.genesisHash)
    }

    private func durabilityJournalFile(_ f: DurabilityFixture) throws -> URL {
        let files = try FileManager.default.contentsOfDirectory(at: f.directory.appendingPathComponent("solana-pending-v1"),
            includingPropertiesForKeys: nil).filter { $0.pathExtension == "journal" }
        return try XCTUnwrap(files.first)
    }

    private func durabilityBroadcaster(_ f: DurabilityFixture, store: SolanaPendingBroadcastStore) throws -> SolanaTransactionBroadcaster {
        SolanaTransactionBroadcaster(rpcClient: try SolanaRpcClient(transport: f.transport, defaultRPCURL: ClusterTransport.custom),
            expectedPayer: Self.sender, store: store, policy: .init(timeout: 0, pollInterval: 0))
    }

    private final class DurabilityJournalFault {
        var written = false
        var failReport = false
        var writes = 0
    }
}

extension SolanaSendServiceTests {
    func testDurabilityHistoricalPreferenceCannotReplaceNewerPayment() throws {
        let f = try durabilityFixture()
        let first = try semanticPublicRecord(scope: f.scope, amount: 1)
        let key = SolanaPendingBroadcastStore.key(for: f.scope)
        let original = try f.store.admit(first, for: f.scope)
        let oldBytes = try XCTUnwrap(f.defaults.data(forKey: key))
        XCTAssertTrue(f.store.clear(original, for: f.scope))
        let second = try semanticPublicRecord(scope: f.scope, amount: 2)
        try f.store.save(second, for: f.scope)
        f.defaults.set(oldBytes, forKey: key)
        let reopened = durabilityStore(defaults: f.defaults, directory: f.directory)
        XCTAssertEqual(reopened.readState(for: f.scope), .pending(second))
        XCTAssertEqual(f.defaults.data(forKey: key), oldBytes, "A stale external mirror is preserved, never adopted")
    }

    func testDurabilityHistoricalPreferenceCannotUndoAcknowledgement() throws {
        let f = try durabilityFixture()
        let snapshot = try f.store.admit(semanticPublicRecord(scope: f.scope), for: f.scope)
        let key = SolanaPendingBroadcastStore.key(for: f.scope)
        let oldBytes = try XCTUnwrap(f.defaults.data(forKey: key))
        XCTAssertTrue(try f.store.markReported(snapshot, for: f.scope))
        f.defaults.set(oldBytes, forKey: key)
        let reopened = durabilityStore(defaults: f.defaults, directory: f.directory)
        XCTAssertEqual(reopened.pending(for: f.scope)?.reportedAsSent, true)
    }

    func testDurabilityHistoricalPreferenceCannotResurrectClearedPayment() throws {
        let f = try durabilityFixture()
        let snapshot = try f.store.admit(semanticPublicRecord(scope: f.scope), for: f.scope)
        let key = SolanaPendingBroadcastStore.key(for: f.scope)
        let oldBytes = try XCTUnwrap(f.defaults.data(forKey: key))
        XCTAssertTrue(f.store.clear(snapshot, for: f.scope))
        f.defaults.set(oldBytes, forKey: key)
        let reopened = durabilityStore(defaults: f.defaults, directory: f.directory)
        XCTAssertEqual(reopened.readState(for: f.scope), .absent)
        XCTAssertEqual(f.defaults.data(forKey: key), oldBytes)
    }

    func testDurabilityNovelConflictRemainsUnreadableAfterMirrorLoss() async throws {
        let f = try durabilityFixture()
        try f.store.save(semanticPublicRecord(scope: f.scope, amount: 1), for: f.scope)
        let key = SolanaPendingBroadcastStore.key(for: f.scope)
        let first = try XCTUnwrap(f.defaults.data(forKey: key))
        let conflict = try semanticEncodedRecord(semanticPublicRecord(scope: f.scope, amount: 2),
            changes: ["unknownConflictField": ["preserve", "exact"]])
        f.defaults.set(conflict, forKey: key)
        XCTAssertEqual(f.store.readState(for: f.scope), .unreadable)
        XCTAssertEqual(f.defaults.data(forKey: key), conflict)
        f.defaults.removeObject(forKey: key)
        let reopened = durabilityStore(defaults: f.defaults, directory: f.directory)
        XCTAssertEqual(reopened.readState(for: f.scope), .unreadable)
        _ = try? await durabilityBroadcaster(f, store: reopened).broadcast(admissionSigned(amount: 3),
            lastValidBlockHeight: 99, scope: f.scope, options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(f.transport.sent, [])
        let history = try String(contentsOf: durabilityJournalFile(f), encoding: .utf8)
        XCTAssertTrue(history.contains(first.base64EncodedString()))
        XCTAssertTrue(history.contains(conflict.base64EncodedString()))
    }

    func testDurabilityMalformedLegacyBytesRemainUnreadableAfterMirrorLoss() throws {
        let f = try durabilityFixture()
        let key = SolanaPendingBroadcastStore.key(for: f.scope)
        let raw = Data("{exact malformed legacy bytes".utf8)
        f.defaults.set(raw, forKey: key)
        XCTAssertEqual(f.store.readState(for: f.scope), .unreadable)
        f.defaults.removeObject(forKey: key)
        let reopened = durabilityStore(defaults: f.defaults, directory: f.directory)
        XCTAssertEqual(reopened.readState(for: f.scope), .unreadable)
        XCTAssertThrowsError(try reopened.save(semanticPublicRecord(scope: f.scope), for: f.scope))
        XCTAssertTrue(try String(contentsOf: durabilityJournalFile(f), encoding: .utf8).contains(raw.base64EncodedString()))
    }

    func testDurabilityWrongTypeLegacyValueRemainsUnreadableAfterMirrorLoss() throws {
        let f = try durabilityFixture()
        let key = SolanaPendingBroadcastStore.key(for: f.scope)
        f.defaults.set(["unknown": ["retained", "value"]], forKey: key)
        XCTAssertEqual(f.store.readState(for: f.scope), .unreadable)
        f.defaults.removeObject(forKey: key)
        let reopened = durabilityStore(defaults: f.defaults, directory: f.directory)
        XCTAssertEqual(reopened.readState(for: f.scope), .unreadable)
        XCTAssertThrowsError(try reopened.save(semanticPublicRecord(scope: f.scope), for: f.scope))
    }

    func testDurabilityArchivedLegacyBytesRemainUnreadableAfterMirrorLoss() async throws {
        let f = try durabilityFixture()
        let key = ["solana.pending_broadcast.unreadable", f.scope.walletId, f.scope.chainId].joined(separator: ":")
        let raw = Data("exact historical archived bytes".utf8)
        f.defaults.set(raw, forKey: key)
        XCTAssertEqual(f.store.readState(for: f.scope), .unreadable)
        f.defaults.removeObject(forKey: key)
        let reopened = durabilityStore(defaults: f.defaults, directory: f.directory)
        XCTAssertEqual(reopened.readState(for: f.scope), .unreadable)
        XCTAssertTrue(try String(contentsOf: durabilityJournalFile(f), encoding: .utf8).contains(raw.base64EncodedString()))
        let other = SolanaPendingBroadcastScope(walletId: f.scope.walletId + "-healthy", chainId: f.scope.chainId)
        XCTAssertEqual(reopened.readState(for: other), .absent)
        let client = try SolanaRpcClient(transport: f.transport, defaultRPCURL: ClusterTransport.custom)
        let balance = try await client.balance(address: Self.sender, commitment: .confirmed, rpcURL: ClusterTransport.custom)
        XCTAssertEqual(balance, 2_000_000_000)
    }
}

extension SolanaSendServiceTests {
    func testDurabilityNativeLockConstructorFailureDoesNotReleaseHeldLock() throws {
        guard ProcessInfo.processInfo.environment["SOLANA_LOCK_PROBE_ENABLED"] == "1" else {
            throw XCTSkip("Requires the isolated simulator child-process lock probe")
        }
        let f = try durabilityFixture()
        let journal = try SolanaPendingBroadcastJournal(parentDirectoryURL: f.directory)
        try journal.withState(for: f.scope) { _ in
            try durabilityLockProbe(directory: f.directory, phase: "before-failed-constructor", expectedAcquired: false)
            XCTAssertThrowsError(try SolanaPendingBroadcastJournal(parentDirectoryURL: f.directory, parentSync: { _ in -1 }))
            try durabilityLockProbe(directory: f.directory, phase: "after-failed-constructor", expectedAcquired: false)
        }
        try durabilityLockProbe(directory: f.directory, phase: "after-release", expectedAcquired: true)
    }

    private func durabilityLockProbe(directory: URL, phase: String, expectedAcquired: Bool) throws {
        let output = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["TON_IMPORT_EVIDENCE_DIR"]))
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let request = output.appendingPathComponent("request-\(phase).json")
        let response = output.appendingPathComponent("response-\(phase).json")
        let lock = directory.appendingPathComponent("solana-pending-v1/.lock")
        let data = try JSONSerialization.data(withJSONObject: ["path": lock.path, "parentPID": getpid(), "phase": phase])
        try data.write(to: request, options: .atomic)
        let deadline = Date().addingTimeInterval(15)
        while !FileManager.default.fileExists(atPath: response.path), Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
        let result = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: response)) as? [String: Any])
        XCTAssertNotEqual((result["pid"] as? NSNumber)?.int32Value, getpid(), "Probe must run in a separate simulator process")
        XCTAssertEqual(result["acquired"] as? Bool, expectedAcquired, phase)
    }
}

extension SolanaSendServiceTests {
    func testDurabilityNativePeerLifecycleAndNestedStateKeepOuterLock() throws {
        guard ProcessInfo.processInfo.environment["SOLANA_LOCK_PROBE_ENABLED"] == "1" else {
            throw XCTSkip("Requires the isolated simulator child-process lock probe")
        }
        let f = try durabilityFixture()
        let journal = try SolanaPendingBroadcastJournal(parentDirectoryURL: f.directory)
        try journal.withState(for: f.scope) { _ in
            var peer: SolanaPendingBroadcastJournal? = try SolanaPendingBroadcastJournal(
                parentDirectoryURL: f.directory.appendingPathComponent("."))
            weak var released = peer
            XCTAssertThrowsError(try peer?.withState(for: f.scope) { _ in XCTFail("Nested state cannot be admitted") })
            try durabilityLockProbe(directory: f.directory, phase: "peer-after-nested-rejection", expectedAcquired: false)
            peer = nil
            XCTAssertNil(released, "A peer must actually deinitialize during the outer operation")
            try durabilityLockProbe(directory: f.directory, phase: "peer-after-deinit", expectedAcquired: false)
        }
        try durabilityLockProbe(directory: f.directory, phase: "peer-after-outer-release", expectedAcquired: true)
        XCTAssertEqual(f.store.readState(for: f.scope), .absent)
    }

    func testDurabilityNativeThrowingMutationReleasesLock() throws {
        guard ProcessInfo.processInfo.environment["SOLANA_LOCK_PROBE_ENABLED"] == "1" else {
            throw XCTSkip("Requires the isolated simulator child-process lock probe")
        }
        let f = try durabilityFixture()
        let journal = try SolanaPendingBroadcastJournal(parentDirectoryURL: f.directory)
        XCTAssertThrowsError(try journal.withState(for: f.scope) { _ in
            throw SolanaPendingBroadcastStoreError.invalidRecord
        })
        try durabilityLockProbe(directory: f.directory, phase: "throw-after-outer-release", expectedAcquired: true)
        try f.store.save(semanticPublicRecord(scope: f.scope), for: f.scope)
        XCTAssertNotNil(f.store.pending(for: f.scope))
    }

    func testDurabilityNovelPreferenceAfterClearCannotAuthorizeNewOutput() async throws {
        let f = try durabilityFixture()
        let snapshot = try f.store.admit(semanticPublicRecord(scope: f.scope), for: f.scope)
        XCTAssertTrue(f.store.clear(snapshot, for: f.scope))
        let conflict = try semanticEncodedRecord(semanticPublicRecord(scope: f.scope, amount: 2), changes: ["future": "exact"])
        let key = SolanaPendingBroadcastStore.key(for: f.scope)
        f.defaults.set(conflict, forKey: key)
        XCTAssertEqual(f.store.readState(for: f.scope), .unreadable)
        f.defaults.removeObject(forKey: key)
        let reopened = durabilityStore(defaults: f.defaults, directory: f.directory)
        _ = try? await durabilityBroadcaster(f, store: reopened).broadcast(admissionSigned(amount: 3),
            lastValidBlockHeight: 99, scope: f.scope, options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(reopened.readState(for: f.scope), .unreadable)
        XCTAssertEqual(f.transport.sent, [])
    }

    func testDurabilityWrongTypeConflictPreservesTypedValueAndOriginalBytes() throws {
        let f = try durabilityFixture()
        try f.store.save(semanticPublicRecord(scope: f.scope), for: f.scope)
        let key = SolanaPendingBroadcastStore.key(for: f.scope)
        let original = try XCTUnwrap(f.defaults.data(forKey: key))
        let value: [String: Any] = ["unknown": ["exact", "typed"], "number": 12, "data": Data([0, 255, 7])]
        f.defaults.set(value, forKey: key)
        XCTAssertEqual(f.store.readState(for: f.scope), .unreadable)
        let lines = try String(contentsOf: durabilityJournalFile(f), encoding: .utf8).split(separator: "\n")
        let entries = try lines.map { try XCTUnwrap(JSONSerialization.jsonObject(with: Data($0.dropFirst(65).utf8)) as? [String: Any]) }
        XCTAssertEqual(entries.first?["record"] as? String, original.base64EncodedString())
        let conflicts = try XCTUnwrap(entries.last?["conflicts"] as? [[String: Any]])
        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts[0]["key"] as? String, key)
        XCTAssertEqual(conflicts[0]["encoding"] as? String, "binary-property-list")
        let bytes = try XCTUnwrap(Data(base64Encoded: XCTUnwrap(conflicts[0]["bytes"] as? String)))
        let restored = try XCTUnwrap(PropertyListSerialization.propertyList(from: bytes, options: [], format: nil) as? [String: Any])
        XCTAssertEqual(restored["value"] as? NSDictionary, value as NSDictionary)
    }

    func testDurabilityInterruptedConflictRetainsExactEvidenceOnReopen() throws {
        let f = try durabilityFixture()
        try f.store.save(semanticPublicRecord(scope: f.scope), for: f.scope)
        let key = SolanaPendingBroadcastStore.key(for: f.scope)
        let conflict = Data("{unreadable external conflict".utf8)
        f.defaults.set(conflict, forKey: key)
        let journal = try SolanaPendingBroadcastJournal(parentDirectoryURL: f.directory) { boundary in
            if case .afterWrite = boundary { throw SolanaPendingBroadcastStoreError.notPersisted }
        }
        let failed = SolanaPendingBroadcastStore(userDefaults: f.defaults, logger: nil, journal: journal)
        XCTAssertEqual(failed.readState(for: f.scope), .unreadable)
        f.defaults.removeObject(forKey: key)
        let reopened = durabilityStore(defaults: f.defaults, directory: f.directory)
        XCTAssertEqual(reopened.readState(for: f.scope), .unreadable)
        XCTAssertThrowsError(try reopened.save(semanticPublicRecord(scope: f.scope, amount: 2), for: f.scope))
        XCTAssertTrue(try String(contentsOf: durabilityJournalFile(f), encoding: .utf8).contains(conflict.base64EncodedString()))
    }
}

// Dedicated host-orchestrated process tests: writer termination is intentional and must
// never be counted as a passing XCTest. The reader is selected in a separate app process.
extension SolanaSendServiceTests {
    func testDurabilityProcessWriterRetainsPublicFixtureBeforeIntentionalTermination() throws {
        let config = try durabilityRestartConfig()
        let parent = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true).appendingPathComponent(config.identifier, isDirectory: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: parent.path), "Every process experiment owns a fresh UUID")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700])
        let defaults = try XCTUnwrap(DurabilityDefaults(suiteName: config.identifier))
        defaults.cacheOnly = true
        let scope = SolanaPendingBroadcastScope(walletId: config.identifier, chainId: "solana")
        var record = config.mode == "unbound" ? legacyClusterRecord(scope: scope) : try semanticPublicRecord(scope: scope)
        let expectedState = config.mode == "clear" ? "absent" : ["conflict", "truncated"].contains(config.mode) ? "unreadable" : "pending"
        let journal = try SolanaPendingBroadcastJournal(parentDirectoryURL: parent, writeBytes: { fd, bytes, count in
            guard config.mode == "truncated" else { return Darwin.write(fd, bytes, count) }
            let written = Darwin.write(fd, bytes, max(1, count / 2))
            XCTAssertGreaterThan(written, 0)
            do {
                try self.durabilityRestartMarker(config, parent: parent, defaults: defaults,
                    record: record, expectedState: expectedState)
            } catch { XCTFail("Partial-write marker failed: \(error)"); return -1 }
            _ = Darwin.kill(getpid(), SIGKILL)
            return -1
        }) { boundary in
            if config.mode == "partial", case .afterWrite = boundary {
                try self.durabilityRestartMarker(config, parent: parent, defaults: defaults,
                    record: record, expectedState: expectedState)
                _ = Darwin.kill(getpid(), SIGKILL)
                throw SolanaPendingBroadcastStoreError.notPersisted
            }
        }
        let store = SolanaPendingBroadcastStore(userDefaults: defaults, logger: nil, journal: journal)
        let snapshot: SolanaPendingBroadcastSnapshot
        if config.mode == "unbound" {
            let original = try semanticEncodedRecord(record, changes: ["unknownLegacy": ["exact", "preserved"]])
            defaults.set(original, forKey: SolanaPendingBroadcastStore.key(for: scope))
            snapshot = try XCTUnwrap(store.snapshot(for: scope))
        } else { snapshot = try store.admit(record, for: scope) }
        switch config.mode {
        case "ack":
            XCTAssertTrue(try store.markReported(snapshot, for: scope)); record.reportedAsSent = true
        case "clear": XCTAssertTrue(store.clear(snapshot, for: scope))
        case "conflict":
            defaults.set(Data("{exact process conflict".utf8), forKey: SolanaPendingBroadcastStore.key(for: scope))
            XCTAssertEqual(store.readState(for: scope), .unreadable)
        default: XCTAssertEqual(store.readState(for: scope), .pending(record))
        }
        try durabilityRestartMarker(config, parent: parent, defaults: defaults, record: record, expectedState: expectedState)
        _ = Darwin.kill(getpid(), SIGKILL)
        XCTFail("The isolated writer must terminate before any XCTest success can be recorded")
    }

    func testDurabilityProcessReaderReopensExactRetainedAuthority() throws {
        let config = try durabilityRestartConfig()
        let marker = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: config.marker)) as? [String: Any])
        XCTAssertEqual(marker["identifier"] as? String, config.identifier)
        XCTAssertEqual(marker["mode"] as? String, config.mode)
        XCTAssertNotEqual((marker["writerPID"] as? NSNumber)?.int32Value, getpid())
        // Xcode may relocate the preserved data container when installing the same reader.
        // Resolve the original UUID beneath the current app root; never copy/rebuild its journal.
        let parent = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false).appendingPathComponent(config.identifier, isDirectory: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: parent.path))
        let scope = SolanaPendingBroadcastScope(walletId: config.identifier, chainId: "solana")
        let defaults = try XCTUnwrap(UserDefaults(suiteName: config.identifier))
        XCTAssertNil(defaults.object(forKey: SolanaPendingBroadcastStore.key(for: scope)), "Writer used only an ephemeral preference cache")
        let originalFile = URL(fileURLWithPath: try XCTUnwrap(marker["journalFile"] as? String))
        let file = parent.appendingPathComponent("solana-pending-v1").appendingPathComponent(originalFile.lastPathComponent)
        let expectedHistory = try XCTUnwrap(Data(base64Encoded: XCTUnwrap(marker["journalBytes"] as? String)))
        XCTAssertEqual(try Data(contentsOf: file), expectedHistory)
        let store = try SolanaPendingBroadcastStore(userDefaults: defaults, logger: nil,
            journal: SolanaPendingBroadcastJournal(parentDirectoryURL: parent))
        let expected = try XCTUnwrap(marker["expectedState"] as? String)
        switch expected {
        case "absent": XCTAssertEqual(store.readState(for: scope), .absent)
        case "unreadable":
            XCTAssertEqual(store.readState(for: scope), .unreadable)
            XCTAssertThrowsError(try store.admit(semanticPublicRecord(scope: scope, amount: 2), for: scope))
        case "pending":
            let bytes = try XCTUnwrap(Data(base64Encoded: XCTUnwrap(marker["expectedRecord"] as? String)))
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970
            let record = try decoder.decode(SolanaPendingBroadcast.self, from: bytes)
            XCTAssertEqual(store.readState(for: scope), .pending(record))
            XCTAssertThrowsError(try store.admit(semanticPublicRecord(scope: scope, amount: 2), for: scope))
        default: XCTFail("Unrecognized experiment state")
        }
        XCTAssertEqual(try Data(contentsOf: file), expectedHistory, "Reopen synchronizes, never rewrites the retained history")
        let output = URL(fileURLWithPath: try XCTUnwrap(ProcessInfo.processInfo.environment["TON_IMPORT_EVIDENCE_DIR"]))
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: ["readerPID": getpid(), "writerPID": XCTUnwrap(marker["writerPID"]),
            "identifier": config.identifier, "mode": config.mode, "journalBytes": Data(contentsOf: file).base64EncodedString(),
            "expectedState": expected, "journalFile": file.path, "directory": parent.path]).write(
                to: output.appendingPathComponent("reader-proof.json"), options: .atomic)
    }

    private struct DurabilityRestartConfig {
        let identifier: String
        let mode: String
        let marker: URL
    }

    private func durabilityRestartConfig() throws -> DurabilityRestartConfig {
        let environment = ProcessInfo.processInfo.environment
        guard let identifier = environment["SOLANA_RESTART_ID"], let mode = environment["SOLANA_RESTART_MODE"],
              let marker = environment["SOLANA_RESTART_MARKER"] else {
            throw XCTSkip("Requires the isolated writer-kill-reader process harness")
        }
        XCTAssertTrue(identifier.hasPrefix("solana-restart-"))
        XCTAssertTrue(["pending", "ack", "clear", "conflict", "unbound", "partial", "truncated"].contains(mode))
        return DurabilityRestartConfig(identifier: identifier, mode: mode, marker: URL(fileURLWithPath: marker))
    }

    private func durabilityRestartMarker(
        _ config: DurabilityRestartConfig, parent: URL, defaults: UserDefaults,
        record: SolanaPendingBroadcast, expectedState: String
    ) throws {
        let files = try FileManager.default.contentsOfDirectory(at: parent.appendingPathComponent("solana-pending-v1"),
            includingPropertiesForKeys: nil).filter { $0.pathExtension == "journal" }
        XCTAssertEqual(files.count, 1)
        let file = try XCTUnwrap(files.first)
        let scope = SolanaPendingBroadcastScope(walletId: config.identifier, chainId: "solana")
        let marker: [String: Any] = ["identifier": config.identifier, "mode": config.mode, "writerPID": getpid(),
            "directory": parent.path, "journalFile": file.path, "journalBytes": try Data(contentsOf: file).base64EncodedString(),
            "expectedState": expectedState, "expectedRecord": try semanticEncodedRecord(record).base64EncodedString(),
            "preferenceCache": defaults.data(forKey: SolanaPendingBroadcastStore.key(for: scope))?.base64EncodedString() ?? ""]
        try FileManager.default.createDirectory(at: config.marker.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: marker, options: .sortedKeys).write(to: config.marker, options: .atomic)
    }
}


// Actual factory acquisition failure followed by restored local storage. The baseline
// keeps the production one-shot Result capture unchanged; only its factory is injectable.
extension SolanaSendServiceTests {
    func testDurabilityTransientJournalInitializationCanRecoverSameStore() async throws {
        let f = try durabilityFixture(cacheOnly: true)
        var unavailable = true
        let store = SolanaPendingBroadcastStore(userDefaults: f.defaults, logger: nil, journalFactory: {
            try SolanaPendingBroadcastJournal(parentDirectoryURL: f.directory,
                parentSync: { fd in unavailable ? -1 : Darwin.fsync(fd) })
        })
        XCTAssertEqual(store.readState(for: f.scope), .unreadable)
        let broadcaster = try durabilityBroadcaster(f, store: store)
        _ = try? await broadcaster.broadcast(admissionSigned(amount: 1), lastValidBlockHeight: 99,
            scope: f.scope, options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(f.transport.sent, [])
        unavailable = false
        XCTAssertEqual(store.readState(for: f.scope), .absent, "Restored storage must be usable without restarting the wallet")
        let record = try semanticPublicRecord(scope: f.scope)
        _ = try store.admit(record, for: f.scope)
        XCTAssertEqual(store.readState(for: f.scope), .pending(record))
    }

    func testDurabilityTransientInitializationRecoversOriginalJournalWithoutPreferenceCache() throws {
        let f = try durabilityFixture(cacheOnly: true)
        let record = try semanticPublicRecord(scope: f.scope)
        _ = try f.store.admit(record, for: f.scope)
        let file = try durabilityJournalFile(f)
        let original = try Data(contentsOf: file)
        var unavailable = true
        let store = SolanaPendingBroadcastStore(userDefaults: try XCTUnwrap(UserDefaults(suiteName: f.suite)),
            logger: nil, journalFactory: {
                try SolanaPendingBroadcastJournal(parentDirectoryURL: f.directory,
                    parentSync: { fd in unavailable ? -1 : Darwin.fsync(fd) })
            })
        XCTAssertEqual(store.readState(for: f.scope), .unreadable)
        unavailable = false
        XCTAssertEqual(store.readState(for: f.scope), .pending(record))
        XCTAssertThrowsError(try store.admit(semanticPublicRecord(scope: f.scope, amount: 2), for: f.scope))
        XCTAssertEqual(try Data(contentsOf: file), original)
    }

    func testDurabilityFactoryRecoveryCannotAdoptCorruptHistory() async throws {
        let f = try durabilityFixture(cacheOnly: true)
        _ = try f.store.admit(semanticPublicRecord(scope: f.scope), for: f.scope)
        let file = try durabilityJournalFile(f)
        var corrupt = try Data(contentsOf: file); corrupt.append(Data("incomplete".utf8))
        try corrupt.write(to: file)
        var unavailable = true
        let store = SolanaPendingBroadcastStore(userDefaults: try XCTUnwrap(UserDefaults(suiteName: f.suite)),
            logger: nil, journalFactory: {
                try SolanaPendingBroadcastJournal(parentDirectoryURL: f.directory,
                    parentSync: { fd in unavailable ? -1 : Darwin.fsync(fd) })
            })
        XCTAssertEqual(store.readState(for: f.scope), .unreadable)
        unavailable = false
        XCTAssertEqual(store.readState(for: f.scope), .unreadable)
        let broadcaster = try durabilityBroadcaster(f, store: store)
        _ = try? await broadcaster.broadcast(admissionSigned(amount: 2), lastValidBlockHeight: 99,
            scope: f.scope, options: SolanaBroadcastOptions(), rpcURL: ClusterTransport.custom)
        XCTAssertEqual(f.transport.sent, [])
        XCTAssertEqual(try Data(contentsOf: file), corrupt)
    }
}


extension SolanaSendServiceTests {
    func testDurabilityJournalFactorySuccessIsCachedAndReentryFailsClosed() throws {
        let f = try durabilityFixture()
        var store: SolanaPendingBroadcastStore?
        var calls = 0
        var reentrantState: SolanaPendingBroadcastReadState?
        store = SolanaPendingBroadcastStore(userDefaults: f.defaults, logger: nil, journalFactory: {
            calls += 1
            reentrantState = store?.readState(for: f.scope)
            return try SolanaPendingBroadcastJournal(parentDirectoryURL: f.directory)
        })
        let actual = try XCTUnwrap(store)
        XCTAssertEqual(actual.readState(for: f.scope), .absent)
        XCTAssertEqual(reentrantState, .unreadable)
        let other = SolanaPendingBroadcastScope(walletId: f.scope.walletId + "-other", chainId: f.scope.chainId)
        XCTAssertEqual(actual.readState(for: other), .absent)
        XCTAssertEqual(calls, 1, "A successful immutable directory lease is reused")
    }

    func testDurabilityConcurrentAcquisitionCannotBypassHeldFactory() throws {
        let f = try durabilityFixture()
        let entered = expectation(description: "actual factory held")
        let finished = expectation(description: "first reader completed")
        let release = DispatchSemaphore(value: 0)
        var calls = 0
        let store = SolanaPendingBroadcastStore(userDefaults: f.defaults, logger: nil, journalFactory: {
            calls += 1
            entered.fulfill()
            guard release.wait(timeout: .now() + 5) == .success else {
                XCTFail("Factory release missing"); throw SolanaPendingBroadcastStoreError.notPersisted
            }
            return try SolanaPendingBroadcastJournal(parentDirectoryURL: f.directory)
        })
        DispatchQueue.global().async {
            XCTAssertEqual(store.readState(for: f.scope), .absent)
            finished.fulfill()
        }
        wait(for: [entered], timeout: 5)
        XCTAssertEqual(store.readState(for: f.scope), .unreadable, "An in-flight open cannot claim absence")
        release.signal()
        wait(for: [finished], timeout: 5)
        XCTAssertEqual(store.readState(for: f.scope), .absent)
        XCTAssertEqual(calls, 1)
    }
}
