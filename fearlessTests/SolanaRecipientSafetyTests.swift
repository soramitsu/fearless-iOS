import BigInt
@testable import fearless
import SSFModels
import XCTest

/// IOSUX-4: a Solana transfer never sends funds where nobody can spend them (S1), says why
/// before signing when the network's rent rules would refuse it (S2), and never pays twice
/// when the outcome of a broadcast is unknown (S3).
final class SolanaRecipientSafetyTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Sends are enabled by default; start from no remembered remote veto.
        MultiChainFeaturePolicy.liftRememberedVetoes()
    }

    // MARK: - S1 recipient safety

    func testOffCurveRecipientRejectedForTokenSend() async throws {
        // The USDC associated token account of the reference wallet, as
        // `solana find-program-derived-address` (solana-cli 4.3.0) derives it.
        XCTAssertEqual(
            try SolanaTransferTransactionBuilder.deriveAssociatedTokenAccountAddress(
                walletAddress: Self.referenceWallet,
                mintAddress: Self.usdcMint,
                tokenProgram: .splToken
            ),
            Self.referenceWalletUsdcAccount
        )
        XCTAssertFalse(SolanaTransferTransactionBuilder.isOnEd25519Curve(address: Self.referenceWalletUsdcAccount))
        XCTAssertTrue(SolanaTransferTransactionBuilder.isOnEd25519Curve(address: Self.referenceWallet))

        let rpc = ScriptedSolanaRpc()
        await assertRefusal(.recipientNotWallet) {
            _ = try await SolanaRecipientValidator.validateRecipientAddress(
                Self.referenceWalletUsdcAccount,
                purpose: .tokenTransfer,
                rpcClient: rpc,
                rpcURL: nil
            )
        }
        XCTAssertTrue(rpc.methods.isEmpty, "Refused before asking any node")
    }

    func testTokenSendToTokenAccount_thenNothingIsSignedOrSent() async throws {
        let rpc = ScriptedSolanaRpc()
        let service = try makeService(
            rpc: rpc,
            balances: ScriptedSolanaBalances(nativeLamports: 2_000_000_000, tokens: [Self.senderUsdcHolding])
        )
        let transfer = Self.transfer(asset: Self.usdcAsset, amount: 1_000_000, receiver: Self.referenceWalletUsdcAccount)

        await assertRefusal(.recipientNotWallet) {
            _ = try await service.estimateFee(for: transfer)
        }
        await assertRefusal(.recipientNotWallet) {
            _ = try await service.submit(transfer: transfer)
        }

        XCTAssertFalse(rpc.methods.contains("getLatestBlockhash"), "Nothing was built or signed")
        XCTAssertTrue(rpc.sentTransactions.isEmpty)
    }

    func testTokenProgramOwnedRecipientRejected() async throws {
        // A token account created from its own keypair is on the curve, so only its owner shows it.
        let keypairTokenAccount = try Self.address(index: 11)
        XCTAssertTrue(SolanaTransferTransactionBuilder.isOnEd25519Curve(address: keypairTokenAccount))

        for owner in [SolanaTransferTransactionBuilder.splTokenProgramAddress, SolanaTransferTransactionBuilder.token2022ProgramAddress] {
            let rpc = ScriptedSolanaRpc()
            rpc.accounts[keypairTokenAccount] = SolanaAccountInfo(owner: owner, lamports: 2_039_280, executable: false)

            for purpose in [SolanaRecipientValidator.Purpose.tokenTransfer, .nativeTransfer] {
                await assertRefusal(.recipientIsTokenAccount) {
                    _ = try await SolanaRecipientValidator.validateRecipientAddress(
                        keypairTokenAccount,
                        purpose: purpose,
                        rpcClient: rpc,
                        rpcURL: nil
                    )
                }
            }
        }
    }

    func testProgramRecipientRejected() async {
        let rpc = ScriptedSolanaRpc()
        let program = SolanaTransferTransactionBuilder.associatedTokenProgramAddress
        rpc.accounts[program] = SolanaAccountInfo(
            owner: "BPFLoaderUpgradeab1e11111111111111111111111",
            lamports: 1_141_440,
            executable: true
        )

        await assertRefusal(.recipientIsProgram) {
            _ = try await SolanaRecipientValidator.validateRecipientAddress(
                program,
                purpose: .nativeTransfer,
                rpcClient: rpc,
                rpcURL: nil
            )
        }
    }

    func testRegularWalletRecipientAccepted() async throws {
        let rpc = ScriptedSolanaRpc()
        let funded = try Self.address(index: 12)
        rpc.accounts[funded] = SolanaAccountInfo(owner: Self.systemProgram, lamports: 5_000_000, executable: false)

        for purpose in [SolanaRecipientValidator.Purpose.tokenTransfer, .nativeTransfer] {
            let existing = try await SolanaRecipientValidator.validateRecipientAddress(
                "  \(funded)\n",
                purpose: purpose,
                rpcClient: rpc,
                rpcURL: nil
            )
            XCTAssertEqual(existing.address, funded)
            XCTAssertEqual(existing.account?.owner, Self.systemProgram)

            let unused = try await SolanaRecipientValidator.validateRecipientAddress(
                Self.referenceWallet,
                purpose: purpose,
                rpcClient: rpc,
                rpcURL: nil
            )
            XCTAssertNil(unused.account, "A wallet that has never received anything is still a wallet")
        }
    }

    /// Multisig vaults are system accounts at program-derived addresses: SOL may go there, tokens may not.
    func testOffCurveSystemAccountAcceptedForSolOnly() async throws {
        let rpc = ScriptedSolanaRpc()
        let vault = Self.referenceWalletUsdcAccount
        rpc.accounts[vault] = SolanaAccountInfo(owner: Self.systemProgram, lamports: 10_000_000, executable: false)

        let accepted = try await SolanaRecipientValidator.validateRecipientAddress(
            vault,
            purpose: .nativeTransfer,
            rpcClient: rpc,
            rpcURL: nil
        )
        XCTAssertEqual(accepted.address, vault)
        await assertRefusal(.recipientNotWallet) {
            _ = try await SolanaRecipientValidator.validateRecipientAddress(
                vault,
                purpose: .tokenTransfer,
                rpcClient: rpc,
                rpcURL: nil
            )
        }
    }

    func testMalformedRecipientRejectedWithoutNetworkCall() async {
        let rpc = ScriptedSolanaRpc()
        for recipient in ["", "not-base58", "0OIl" + String(repeating: "1", count: 40), "bc1qslk39wvggqa0vl8nd6jckaz54dw3vk45c5w60m"] {
            await assertRefusal(.invalidRecipient) {
                _ = try await SolanaRecipientValidator.validateRecipientAddress(
                    recipient,
                    purpose: .nativeTransfer,
                    rpcClient: rpc,
                    rpcURL: nil
                )
            }
        }
        XCTAssertTrue(rpc.methods.isEmpty)
    }

    func testRecipientRefusalsSayWhatToDoAndThatNothingWasSent() {
        let refusals: [SolanaTransferRefusal] = [
            .invalidRecipient,
            .recipientNotWallet,
            .recipientIsTokenAccount,
            .recipientIsProgram,
            .amountBelowNewAccountMinimum(minimumLamports: 890_880),
            .remainderBelowAccountMinimum(minimumLamports: 890_880),
            .insufficientSol,
            .insufficientTokenBalance
        ]
        for refusal in refusals {
            let content = refusal.toErrorContent(for: Locale(identifier: "en_US"))
            XCTAssertFalse(content.title.isEmpty, "\(refusal)")
            XCTAssertTrue(content.message.contains("Nothing was sent"), "\(refusal)")
        }
        XCTAssertTrue(
            SolanaTransferRefusal.recipientIsTokenAccount.toErrorContent(for: Locale(identifier: "en")).message
                .contains("Ask the recipient for their Solana wallet address")
        )
        XCTAssertTrue(
            SolanaTransferRefusal.amountBelowNewAccountMinimum(minimumLamports: 890_880)
                .toErrorContent(for: Locale(identifier: "en_US")).message.contains("0.00089088 SOL")
        )
    }

    // MARK: - S2 rent-exempt minimum

    func testNativeSendBelowRentToNewAccountRejectedWithSpecificError() async throws {
        let rpc = ScriptedSolanaRpc()
        let service = try makeService(rpc: rpc, balances: ScriptedSolanaBalances(nativeLamports: 2_000_000_000))
        let recipient = try Self.address(index: 13)

        await assertRefusal(.amountBelowNewAccountMinimum(minimumLamports: 890_880)) {
            _ = try await service.submit(transfer: Self.transfer(amount: 890_879, receiver: recipient))
        }
        XCTAssertFalse(rpc.methods.contains("simulateTransaction"))
        XCTAssertTrue(rpc.sentTransactions.isEmpty)

        // The same amount to an account that already exists needs no minimum.
        rpc.accounts[recipient] = SolanaAccountInfo(owner: Self.systemProgram, lamports: 1, executable: false)
        _ = try await service.submit(transfer: Self.transfer(amount: 890_879, receiver: recipient))
        XCTAssertEqual(rpc.sentTransactions.count, 1)
    }

    func testSenderRemainderBelowRentRejected() async throws {
        let recipient = try Self.address(index: 14)
        let amount: Int64 = 10_000_000
        let fee = ScriptedSolanaRpc.feeLamports

        let rpc = ScriptedSolanaRpc()
        let leavesDust = try makeService(
            rpc: rpc,
            balances: ScriptedSolanaBalances(nativeLamports: amount + fee + 100_000)
        )
        await assertRefusal(.remainderBelowAccountMinimum(minimumLamports: 890_880)) {
            _ = try await leavesDust.submit(transfer: Self.transfer(amount: amount, receiver: recipient))
        }
        XCTAssertTrue(rpc.sentTransactions.isEmpty)

        // Sending everything leaves nothing, which the network accepts.
        let sendAll = try makeService(rpc: rpc, balances: ScriptedSolanaBalances(nativeLamports: amount + fee))
        _ = try await sendAll.submit(transfer: Self.transfer(amount: amount, receiver: recipient))
        XCTAssertEqual(rpc.sentTransactions.count, 1)
    }

    func testRentRulesAtTheirBoundaries() throws {
        let rules = SolanaRentRules(rentExemptMinimumLamports: 890_880, recipientExists: false)

        XCTAssertNoThrow(try SolanaSendService.checkRentRules(rules, lamports: 890_880, feeLamports: 5000, senderBalance: 895_880))
        XCTAssertNoThrow(try SolanaSendService.checkRentRules(rules, lamports: 890_880, feeLamports: 5000, senderBalance: 1_786_760))
        XCTAssertThrowsError(try SolanaSendService.checkRentRules(rules, lamports: 890_880, feeLamports: 5000, senderBalance: 1_786_759)) {
            XCTAssertEqual($0 as? SolanaTransferRefusal, .remainderBelowAccountMinimum(minimumLamports: 890_880))
        }
        XCTAssertThrowsError(try SolanaSendService.checkRentRules(rules, lamports: 890_880, feeLamports: 5000, senderBalance: 895_879)) {
            XCTAssertEqual($0 as? SolanaSendServiceError, .insufficientSolBalance)
        }
        XCTAssertThrowsError(try SolanaSendService.checkRentRules(rules, lamports: .max, feeLamports: .max, senderBalance: .max)) {
            XCTAssertEqual($0 as? SolanaSendServiceError, .insufficientSolBalance)
        }
    }

    // MARK: - S3 ambiguous broadcasts

    func testAmbiguousBroadcastResolvedBySignatureStatus() async throws {
        let rpc = ScriptedSolanaRpc()
        rpc.sendResults = [.failure(URLError(.timedOut))]
        rpc.statuses = [nil, Self.confirmed]
        let store = Self.isolatedStore()
        let signed = try Self.signedTransfer()

        let outcome = try await makeBroadcaster(rpc: rpc, store: store).broadcast(
            signed,
            lastValidBlockHeight: 1000,
            scope: Self.scope,
            options: SolanaBroadcastOptions(),
            rpcURL: nil
        )

        XCTAssertEqual(outcome, .sent(signature: signed.signatureBase58, confirmed: true))
        XCTAssertEqual(rpc.sentTransactions, [signed.signedTransactionBase64], "Sent once, never re-signed")
        XCTAssertNil(store.pending(for: Self.scope))
    }

    func testExpiredBlockhashWithoutSignatureReportsNotSent() async throws {
        let rpc = ScriptedSolanaRpc()
        rpc.sendResults = [.failure(URLError(.networkConnectionLost))]
        rpc.blockhashValid = false
        rpc.expiryWitnesses = Self.twoHosts
        let store = Self.isolatedStore()
        let signed = try Self.signedTransfer()

        let outcome = try await makeBroadcaster(rpc: rpc, store: store).broadcast(
            signed,
            lastValidBlockHeight: 1000,
            blockhashContextSlot: 1,
            scope: Self.scope,
            options: SolanaBroadcastOptions(),
            rpcURL: nil
        )

        XCTAssertEqual(outcome, .notSent(.expired(signature: signed.signatureBase58)))
        XCTAssertNil(store.pending(for: Self.scope), "An expired transaction can never land; the record goes")
    }

    // MARK: - Expiry needs two hosts and a recent record

    /// One node's backend may lack the slot's history and answer nothing for a transaction that
    /// landed. An expiry that only one host proved releases the record without saying nothing
    /// left the wallet.
    func testExpiry_whenOneHostProvesIt_thenTheTransferIsUnverifiedAndTheRecordIsReleased() async throws {
        let rpc = ScriptedSolanaRpc()
        rpc.sendResults = [.failure(URLError(.networkConnectionLost))]
        rpc.blockhashValid = false
        let store = Self.isolatedStore()
        let signed = try Self.signedTransfer()

        let outcome = try await makeBroadcaster(rpc: rpc, store: store).broadcast(
            signed, lastValidBlockHeight: 1000, blockhashContextSlot: 1, scope: Self.scope,
            options: SolanaBroadcastOptions(), rpcURL: nil
        )

        XCTAssertEqual(outcome, .unverified(signature: signed.signatureBase58), "Not \"not sent\"")
        XCTAssertNil(store.pending(for: Self.scope), "Released, so the wallet is never blocked for good")
    }

    /// An earlier record whose expiry only one host proved stops the new transfer once, with
    /// the neutral message, and is released; confirming again sends the new transfer.
    func testPriorRecord_whenOneHostProvesItsExpiry_thenTheNextSendStopsOnceAndThenGoesAhead() async throws {
        let rpc = ScriptedSolanaRpc()
        rpc.sendResults = [.failure(URLError(.timedOut))]
        let store = Self.isolatedStore()
        let service = try makeService(rpc: rpc, balances: ScriptedSolanaBalances(nativeLamports: 2_000_000_000), store: store)
        let transfer = Self.transfer(amount: 10_000_000, receiver: try Self.address(index: 16))
        let first: String
        do {
            _ = try await service.submit(transfer: transfer)
            XCTFail("Expected an unknown outcome")
            return
        } catch let TransferServiceError.solanaBroadcastOutcomeUnknown(signature) {
            first = signature
        }

        rpc.blockhashValid = false
        do {
            _ = try await service.submit(transfer: transfer)
            XCTFail("Expected the new transfer to stop")
        } catch let TransferServiceError.solanaPriorTransferUnverified(signature) {
            XCTAssertEqual(signature, first)
        }
        XCTAssertEqual(rpc.sentTransactions.count, 1, "Nothing new was signed or sent")
        XCTAssertNil(store.pending(for: Self.scope), "The earlier record is released")

        rpc.blockhashValid = true
        rpc.statuses = [Self.confirmed]
        let second = try await service.submit(transfer: Self.transfer(amount: 11_000_000, receiver: transfer.receiver))
        XCTAssertNotEqual(second, first)
        XCTAssertEqual(rpc.sentTransactions.count, 2, "Confirming again sends the new transfer")
    }

    /// Two distinct hosts prove "not sent" only for a record signed less than six hours ago:
    /// nodes prune history, and an older transfer can look absent on both. A signing time in
    /// the future counts as older.
    func testPriorRecord_whenTwoHostsProveItsExpiry_thenOnlyARecentRecordIsNotSent() async throws {
        for (age, expected) in [
            (5 * 3600.0, "clear"), (7 * 3600.0, "unverified"), (-3600.0, "unverified")
        ] {
            let rpc = ScriptedSolanaRpc()
            rpc.sendResults = [.failure(URLError(.timedOut))]
            rpc.expiryWitnesses = Self.twoHosts
            let clock = TestClock()
            let store = Self.isolatedStore()
            let broadcaster = SolanaTransactionBroadcaster(
                rpcClient: rpc, expectedPayer: Self.referenceWallet, store: store, policy: Self.fastPolicy,
                now: clock.now, sleep: { clock.advance($0) }
            )
            let signed = try Self.signedTransfer()
            let outcome = try await broadcaster.broadcast(
                signed, lastValidBlockHeight: 1000, blockhashContextSlot: 1, scope: Self.scope,
                options: SolanaBroadcastOptions(), rpcURL: nil
            )
            XCTAssertEqual(outcome, .unknown(signature: signed.signatureBase58), "\(age)")

            clock.advance(age)
            rpc.blockhashValid = false
            let state = await broadcaster.priorTransferState(scope: Self.scope, rpcURL: nil)

            XCTAssertEqual(
                state,
                expected == "clear" ? .clear : .unverified(signature: signed.signatureBase58),
                "record signed \(age) s before the lookup"
            )
            XCTAssertNil(store.pending(for: Self.scope), "\(age)")
        }
    }

    func testUnknownOutcome_thenNextTransferIsRefusedBeforeSigning() async throws {
        let rpc = ScriptedSolanaRpc()
        rpc.sendResults = [.failure(URLError(.timedOut))]
        let store = Self.isolatedStore()
        let service = try makeService(
            rpc: rpc,
            balances: ScriptedSolanaBalances(nativeLamports: 2_000_000_000),
            store: store
        )
        let recipient = try Self.address(index: 15)

        do {
            _ = try await service.submit(transfer: Self.transfer(amount: 10_000_000, receiver: recipient))
            XCTFail("Expected an unknown outcome")
        } catch let TransferServiceError.solanaBroadcastOutcomeUnknown(signature) {
            XCTAssertEqual(store.pending(for: Self.scope)?.signature, signature)
            let methodsBefore = rpc.methods.count

            do {
                _ = try await service.submit(transfer: Self.transfer(amount: 10_000_000, receiver: recipient))
                XCTFail("Expected the second transfer to wait for the first")
            } catch TransferServiceError.solanaPriorTransferUnresolved(signature) {
                // Expected: the earlier one could still land.
            }
            let secondAttempt = rpc.methods.dropFirst(methodsBefore)
            XCTAssertEqual(Set(secondAttempt), ["getBlock", "isBlockhashValid", "getSignatureStatuses"], "Only the earlier transfer was looked up")
            XCTAssertEqual(rpc.sentTransactions.count, 1)
        }
    }

    func testRetryResendsTheSameBytesAndLandsOnce() async throws {
        let rpc = ScriptedSolanaRpc()
        rpc.sendResults = [.failure(URLError(.timedOut)), .success(())]
        let store = Self.isolatedStore()
        let broadcaster = makeBroadcaster(rpc: rpc, store: store)
        let signed = try Self.signedTransfer()

        let first = try await broadcaster.broadcast(
            signed,
            lastValidBlockHeight: 1000,
            scope: Self.scope,
            options: SolanaBroadcastOptions(),
            rpcURL: nil
        )
        XCTAssertEqual(first, .unknown(signature: signed.signatureBase58))

        rpc.statuses = [Self.confirmed]
        let retried = await broadcaster.retry(
            signature: signed.signatureBase58,
            scope: Self.scope,
            options: SolanaBroadcastOptions(),
            rpcURL: nil
        )

        XCTAssertEqual(retried, .sent(signature: signed.signatureBase58, confirmed: true))
        XCTAssertEqual(rpc.sentTransactions, [signed.signedTransactionBase64, signed.signedTransactionBase64])
        XCTAssertNil(store.pending(for: Self.scope))
        let nothingLeft = await broadcaster.retry(
            signature: signed.signatureBase58,
            scope: Self.scope,
            options: SolanaBroadcastOptions(),
            rpcURL: nil
        )
        XCTAssertNil(nothingLeft, "There is nothing left to retry")
    }

    /// A refusal on a retry ("already processed", "blockhash not found") proves nothing about
    /// the copy already on its way: only the chain can answer.
    func testRetryRefusal_thenTheChainDecides() async throws {
        let rpc = ScriptedSolanaRpc()
        rpc.sendResults = [
            .failure(URLError(.timedOut)),
            .failure(SolanaRpcClientError.rpcError(SolanaJsonRpcErrorPayload(code: -32002, message: "AlreadyProcessed", dataJSON: nil)))
        ]
        let store = Self.isolatedStore()
        let broadcaster = makeBroadcaster(rpc: rpc, store: store)
        let signed = try Self.signedTransfer()
        _ = try await broadcaster.broadcast(signed, lastValidBlockHeight: 1000, scope: Self.scope, options: SolanaBroadcastOptions(), rpcURL: nil)

        rpc.statuses = [Self.confirmed]
        let retried = await broadcaster.retry(signature: signed.signatureBase58, scope: Self.scope, options: SolanaBroadcastOptions(), rpcURL: nil)

        XCTAssertEqual(retried, .sent(signature: signed.signatureBase58, confirmed: true))
    }

    func testFirstAttemptRefusedOrUnreachable_thenNotSentAndRecordCleared() async throws {
        let refusal = SolanaRpcClientError.rpcError(SolanaJsonRpcErrorPayload(code: -32002, message: "Transaction simulation failed", dataJSON: nil))
        let cases: [(Error, SolanaTransferOutcome)] = [
            (SolanaBroadcastFailure(attempts: [.refused(nil), .refused(nil)]), .notSent(.rejectedByNetwork)),
            (refusal, .notSent(.rejectedByNetwork)),
            (URLError(.notConnectedToInternet), .notSent(.noConnection)),
            (SolanaBroadcastFailure(attempts: [.notSent, .refused(nil)]), .notSent(.rejectedByNetwork)),
            (SolanaBroadcastFailure(attempts: [.notSent, .notSent]), .notSent(.noConnection))
        ]
        for (error, expected) in cases {
            let rpc = ScriptedSolanaRpc()
            rpc.sendResults = [.failure(error)]
            let store = Self.isolatedStore()

            let outcome = try await makeBroadcaster(rpc: rpc, store: store).broadcast(
                Self.signedTransfer(),
                lastValidBlockHeight: 1000,
                scope: Self.scope,
                options: SolanaBroadcastOptions(),
                rpcURL: nil
            )

            XCTAssertEqual(outcome, expected, "\(error)")
            XCTAssertNil(store.pending(for: Self.scope), "\(error)")
            XCTAssertFalse(rpc.methods.contains("getSignatureStatuses"), "No lookup is needed when no node took it")
        }
    }

    /// A first submission that every node answered with a code that may follow a relay
    /// (internal error, the server range, a gateway quota) is not "not sent": its outcome is
    /// unknown and its record stays, so no second payment is signed until the chain answers.
    func testFirstSubmission_whenEveryNodeMayHaveRelayedIt_thenTheOutcomeIsUnknownAndTheRecordStays() async throws {
        let signed = try Self.signedTransfer()
        let transport = BroadcastCodeTransport(
            codes: [Self.providerNode: -32603, Self.mainnetBetaNode: -32000, Self.publicNode: -32429],
            signature: signed.signatureBase58
        )
        let store = Self.isolatedStore()

        let outcome = try await makeBroadcaster(transport: transport, store: store).broadcast(
            signed,
            lastValidBlockHeight: 1000,
            scope: Self.scope,
            options: SolanaBroadcastOptions(),
            rpcURL: nil
        )

        XCTAssertEqual(outcome, .unknown(signature: signed.signatureBase58))
        XCTAssertEqual(store.pending(for: Self.scope)?.signature, signed.signatureBase58, "The record stays")
        XCTAssertEqual(transport.sent.map(\.url), [Self.providerNode, Self.mainnetBetaNode, Self.publicNode])
        XCTAssertEqual(Set(transport.sent.map(\.transaction)), [signed.signedTransactionBase64], "The same bytes every time")
        XCTAssertEqual(transport.sent.map(\.skipPreflight), [false, true, true])
    }

    /// A node that judged the first submission before relaying it (a failed simulation, a bad
    /// signature, invalid bytes) has answered for every node: the payment is reported not
    /// sent, its record goes, and no other node is asked.
    func testFirstSubmission_whenTheFirstNodeJudgesIt_thenRejectedAndNoOtherNodeIsAsked() async throws {
        for code in [-32002, -32003, -32602] {
            let signed = try Self.signedTransfer()
            let transport = BroadcastCodeTransport(codes: [Self.providerNode: code], signature: signed.signatureBase58)
            let store = Self.isolatedStore()

            let outcome = try await makeBroadcaster(transport: transport, store: store).broadcast(
                signed,
                lastValidBlockHeight: 1000,
                scope: Self.scope,
                options: SolanaBroadcastOptions(),
                rpcURL: nil
            )

            XCTAssertEqual(outcome, .notSent(.rejectedByNetwork), "\(code)")
            XCTAssertNil(store.pending(for: Self.scope), "\(code)")
            XCTAssertEqual(transport.sent.map(\.url), [Self.providerNode], "\(code)")
        }
    }

    func testRecordThatCannotBeWritten_thenNothingIsBroadcast() async throws {
        let rpc = ScriptedSolanaRpc()

        do {
            _ = try await makeBroadcaster(rpc: rpc, store: UnwritableSolanaPendingStore()).broadcast(
                Self.signedTransfer(),
                lastValidBlockHeight: 1000,
                scope: Self.scope,
                options: SolanaBroadcastOptions(),
                rpcURL: nil
            )
            XCTFail("Expected the broadcast to stop")
        } catch SolanaPendingBroadcastStoreError.notPersisted {
            // Expected.
        }
        XCTAssertTrue(rpc.sentTransactions.isEmpty)
    }

    func testAcceptedButUnconfirmed_thenReportedSentAndCheckedBeforeTheNextTransfer() async throws {
        let rpc = ScriptedSolanaRpc()
        let store = Self.isolatedStore()
        let broadcaster = makeBroadcaster(rpc: rpc, store: store)
        let signed = try Self.signedTransfer()

        let outcome = try await broadcaster.broadcast(signed, lastValidBlockHeight: 1000, blockhashContextSlot: 1,
            scope: Self.scope, options: SolanaBroadcastOptions(), rpcURL: nil)
        XCTAssertEqual(outcome, .sent(signature: signed.signatureBase58, confirmed: false))
        XCTAssertEqual(store.pending(for: Self.scope)?.reportedAsSent, true)

        let stillPending = await broadcaster.priorTransferState(scope: Self.scope, rpcURL: nil)
        XCTAssertEqual(stillPending, .unresolved(signature: signed.signatureBase58))

        rpc.blockhashValid = false
        rpc.expiryWitnesses = Self.twoHosts
        let expired = await broadcaster.priorTransferState(scope: Self.scope, rpcURL: nil)
        XCTAssertEqual(expired, .notSentAfterAll(signature: signed.signatureBase58), "The user is told it did not go through")
        let cleared = await broadcaster.priorTransferState(scope: Self.scope, rpcURL: nil)
        XCTAssertEqual(cleared, .clear)
    }

    func testUnknownOutcomeThatLandedLater_thenUserIsTold() async throws {
        let rpc = ScriptedSolanaRpc()
        rpc.sendResults = [.failure(URLError(.timedOut))]
        let store = Self.isolatedStore()
        let broadcaster = makeBroadcaster(rpc: rpc, store: store)
        let signed = try Self.signedTransfer()
        _ = try await broadcaster.broadcast(signed, lastValidBlockHeight: 1000, scope: Self.scope, options: SolanaBroadcastOptions(), rpcURL: nil)

        rpc.statuses = [Self.confirmed]
        let state = await broadcaster.priorTransferState(scope: Self.scope, rpcURL: nil)

        XCTAssertEqual(state, .sentAfterAll(signature: signed.signatureBase58))
        XCTAssertNil(store.pending(for: Self.scope))
    }

    func testLandedButFailedOnChain_thenReportedAsFailedNotSent() async throws {
        let rpc = ScriptedSolanaRpc()
        rpc.statuses = [SolanaSignatureStatus(slot: 9, confirmationStatus: .confirmed, errorJSON: #"{"InstructionError":[2,{"Custom":1}]}"#)]
        let signed = try Self.signedTransfer()

        let outcome = try await makeBroadcaster(rpc: rpc, store: Self.isolatedStore()).broadcast(
            signed,
            lastValidBlockHeight: 1000,
            scope: Self.scope,
            options: SolanaBroadcastOptions(),
            rpcURL: nil
        )

        XCTAssertEqual(outcome, .failedOnChain(signature: signed.signatureBase58))
    }

    func testLookupFailure_thenPriorTransferStaysUnresolved() async throws {
        let rpc = ScriptedSolanaRpc()
        rpc.sendResults = [.failure(URLError(.timedOut))]
        let store = Self.isolatedStore()
        let broadcaster = makeBroadcaster(rpc: rpc, store: store)
        let signed = try Self.signedTransfer()
        _ = try await broadcaster.broadcast(signed, lastValidBlockHeight: 1000, scope: Self.scope, options: SolanaBroadcastOptions(), rpcURL: nil)

        rpc.lookupError = URLError(.notConnectedToInternet)
        let state = await broadcaster.priorTransferState(scope: Self.scope, rpcURL: nil)

        XCTAssertEqual(state, .unresolved(signature: signed.signatureBase58), "No answer is never taken as \"not sent\"")
        XCTAssertNotNil(store.pending(for: Self.scope))
    }

    // MARK: - Pending broadcast record

    func testPendingRecordSurvivesARestartAndClearsOnlyItsOwnSignature() throws {
        let suite = "solana-pending-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let signed = try Self.signedTransfer()
        let record = SolanaPendingBroadcast(
            walletId: Self.scope.walletId,
            chainId: Self.scope.chainId,
            signature: signed.signatureBase58,
            transactionBase64: signed.signedTransactionBase64,
            lastValidBlockHeight: 1000,
            createdAt: Date(timeIntervalSince1970: 1_760_000_000),
            reportedAsSent: false,
            genesisHash: UniversalWalletRegistry.solanaMainnet.genesisHash
        )
        try SolanaPendingBroadcastStore(userDefaults: defaults, logger: nil).save(record, for: Self.scope)

        // A fresh store over the same defaults is the app after a restart.
        let restarted = SolanaPendingBroadcastStore(userDefaults: defaults, logger: nil)
        XCTAssertEqual(restarted.pending(for: Self.scope), record)
        XCTAssertEqual(
            restarted.pending(for: SolanaPendingBroadcastScope(walletId: Self.scope.walletId, chainId: "solana-mainnet")),
            record,
            "Chain aliases are one network"
        )
        XCTAssertNil(restarted.pending(for: SolanaPendingBroadcastScope(walletId: "other", chainId: Self.scope.chainId)))

        restarted.clear(signature: "someone-else", for: Self.scope)
        XCTAssertEqual(restarted.pending(for: Self.scope), record)
        restarted.clear(signature: record.signature, for: Self.scope)
        XCTAssertNil(restarted.pending(for: Self.scope))
        XCTAssertFalse(try String(decoding: JSONEncoder().encode(record), as: UTF8.self).contains(Self.mnemonic))
    }

    func testUnreadablePendingRecordRemainsInPlaceAndCannotAuthorizeReplacement() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "solana-pending-\(UUID().uuidString)"))
        let key = SolanaPendingBroadcastStore.key(for: Self.scope)
        defaults.set(Data("{not json".utf8), forKey: key)

        let store = SolanaPendingBroadcastStore(userDefaults: defaults, logger: nil)

        XCTAssertNil(store.pending(for: Self.scope))
        XCTAssertEqual(store.readState(for: Self.scope), .unreadable)
        XCTAssertEqual(defaults.data(forKey: key), Data("{not json".utf8))
        XCTAssertNil(defaults.object(forKey: "solana.pending_broadcast.unreadable:\(Self.scope.walletId):\(Self.scope.chainId)"))
    }

    // MARK: - Builders

    private func makeService(
        rpc: ScriptedSolanaRpc,
        balances: ScriptedSolanaBalances,
        store: SolanaPendingBroadcastStoring = SolanaRecipientSafetyTests.isolatedStore()
    ) throws -> SolanaTransferService {
        try SolanaTransferService(
            wallet: Self.wallet,
            chain: Self.chain,
            rpcClient: rpc,
            balanceSync: balances,
            mnemonicProvider: StaticSolanaMnemonicProvider(mnemonic: Self.mnemonic),
            sendGate: .production,
            pendingStore: store,
            confirmationPolicy: Self.fastPolicy,
            providerRPCURL: nil
        )
    }

    private func makeBroadcaster(rpc: ScriptedSolanaRpc, store: SolanaPendingBroadcastStoring) -> SolanaTransactionBroadcaster {
        SolanaTransactionBroadcaster(rpcClient: rpc, expectedPayer: Self.referenceWallet, store: store, policy: Self.fastPolicy, sleep: { _ in })
    }

    /// The app's own failover client over three nodes whose answers `transport` scripts.
    private func makeBroadcaster(transport: BroadcastCodeTransport, store: SolanaPendingBroadcastStoring) throws -> SolanaTransactionBroadcaster {
        let rpc = try SolanaFailoverRpcClient(
            endpoints: [Self.providerNode, Self.mainnetBetaNode, Self.publicNode],
            transport: transport,
            health: UniversalWalletEndpointHealth()
        )
        return SolanaTransactionBroadcaster(rpcClient: rpc, expectedPayer: Self.referenceWallet, store: store, policy: Self.fastPolicy, sleep: { _ in })
    }

    private static let providerNode = "https://solana-mainnet.example-provider.com/v2/fixture"
    private static let mainnetBetaNode = "https://api.mainnet-beta.solana.com"
    private static let publicNode = "https://solana-rpc.publicnode.com"

    private func assertRefusal(
        _ expected: SolanaTransferRefusal,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () async throws -> Void
    ) async {
        do {
            try await block()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? SolanaTransferRefusal, expected, "\(error)", file: file, line: line)
        }
    }

    /// Polls a handful of times without waiting, so an unresolved outcome is reached at once.
    private static let fastPolicy = SolanaConfirmationPolicy(timeout: 0.05, pollInterval: 0.01)
    /// Two distinct hosts that each proved an expiry.
    private static let twoHosts: Set<String> = ["api.mainnet-beta.solana.com", "public.rpc.solanavibestation.com"]
    private static let confirmed = SolanaSignatureStatus(slot: 9, confirmationStatus: .confirmed, errorJSON: nil)

    static func isolatedStore() -> SolanaPendingBroadcastStore {
        SolanaPendingBroadcastStore(
            userDefaults: UserDefaults(suiteName: "solana-recipient-safety-\(UUID().uuidString)")!,
            logger: nil
        )
    }

    private static func signedTransfer() throws -> SignedSolanaTransaction {
        let unsigned = try SolanaTransferTransactionBuilder.buildNativeTransfer(
            senderAddress: referenceWallet,
            recipientAddress: address(index: 16),
            lamports: 1_000_000,
            recentBlockhash: "7GjNiPun3AzEazTZoFEjZgcBMeuaXdpjHq2raZTmTrfs",
            computeBudget: SolanaComputeBudget(unitLimit: 2000, unitPriceMicroLamports: 1000)
        )
        return try SolanaTransactionSigner.signSerializedTransaction(
            mnemonic: mnemonic,
            transactionBase64: unsigned.transactionBase64,
            expectedSigner: referenceWallet
        )
    }

    private static func transfer(asset: AssetModel = solAsset, amount: Int64, receiver: String) -> Transfer {
        Transfer(
            chainAsset: ChainAsset(chain: chain, asset: asset),
            amount: BigUInt(UInt64(amount)),
            receiver: receiver,
            tip: nil,
            appId: nil
        )
    }

    private static func address(index: Int) throws -> String {
        try SolanaKeyDerivation.deriveAccount(mnemonic: mnemonic, derivationPath: "m/44'/501'/\(index)'/0'").address
    }

    private static let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
    /// What Phantom shows for the phrase above (m/44'/501'/0'/0').
    private static let referenceWallet = "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk"
    private static let usdcMint = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"
    private static let referenceWalletUsdcAccount = "5N3f1tj9v1vc5TUZ8S7mCAnVmjVKrfnzXWhxLaxyZAgt"
    private static let systemProgram = "11111111111111111111111111111111"

    private static let solAsset = AssetModel(id: "SOL", name: "Solana", symbol: "SOL", precision: 9, isUtility: true, isNative: true)
    private static let usdcAsset = AssetModel(
        id: usdcMint,
        name: "USD Coin",
        symbol: "USDC",
        precision: 6,
        currencyId: usdcMint,
        isUtility: false,
        isNative: false
    )
    private static let chain: ChainModel = {
        let chain = UniversalWalletRegistry.solanaMainnetChainModel
        return ChainModel(
            rank: chain.rank,
            disabled: false,
            chainId: chain.chainId,
            parentId: nil,
            paraId: nil,
            name: chain.name,
            assets: [solAsset, usdcAsset],
            xcm: nil,
            nodes: chain.nodes,
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }()

    private static let wallet: MetaAccountModel = {
        let account = try! SolanaKeyDerivation.deriveAccount(mnemonic: mnemonic)
        return AccountGenerator.generateMetaAccount(with: [
            ChainAccountModel(
                chainId: UniversalWalletRegistry.solanaMainnet.chainId,
                accountId: account.publicKey,
                publicKey: account.publicKey,
                cryptoType: CryptoType.ed25519.rawValue,
                ethereumBased: false
            )
        ])
    }()

    private static let scope = SolanaPendingBroadcastScope(walletId: wallet.metaId, chainId: UniversalWalletRegistry.solanaMainnet.chainId)

    private static let senderUsdcHolding = UniversalWalletIndexedAssetBalance(
        accountId: "solana-mainnet",
        ecosystem: .solana,
        chainId: "solana:mainnet",
        assetId: usdcMint,
        amount: "5000000",
        decimals: 6,
        isNative: false,
        tokenAccountId: try! SolanaTransferTransactionBuilder.deriveAssociatedTokenAccountAddress(
            walletAddress: referenceWallet,
            mintAddress: usdcMint,
            tokenProgram: .splToken
        ),
        contractAddress: usdcMint,
        tokenProgram: "spl-token",
        syncedAtMillis: 1
    )
}

// MARK: - Doubles

/// A Solana cluster the test scripts: accounts, rent, fee, broadcast replies, block heights
/// and signature statuses. It records every method it is asked, in order.
final class ScriptedSolanaRpc: SolanaRpcClientProtocol {
    // Explicit protocol fixture binding; endpoint attestation is tested with actual clients separately.
    var expectedGenesisHash: String? = UniversalWalletRegistry.solanaMainnet.genesisHash
    func bound(toGenesisHash genesisHash: String) throws -> SolanaRpcClientProtocol {
        expectedGenesisHash = genesisHash
        return self
    }
    func verifyCluster(rpcURL _: String?) async throws { try Task.checkCancellation() }

    static let feeLamports: Int64 = 5000

    var accounts: [String: SolanaAccountInfo] = [:]
    var emptyAccountRent: Int64 = 890_880
    var tokenAccountRent: Int64 = 2_039_280
    var lastValidBlockHeight: Int64 = 1000
    /// Consumed one per call; the last value repeats. Defaults to a height below expiry.
    var blockHeights: [Int64] = [900]
    var blockhashValid = true
    /// Consumed one per lookup; the last value repeats. Defaults to "not seen".
    var statuses: [SolanaSignatureStatus?] = [nil]
    /// Consumed one per broadcast; success returns the transaction's own signature.
    var sendResults: [Result<Void, Error>] = []
    var lookupError: Error?
    /// Token accounts by program id, as `getTokenAccountsByOwner` reports them.
    var tokenAccounts: [String: [SolanaParsedTokenAccount]] = [:]
    var readError: Error?
    /// Fails only `getTokenAccountsByOwner`, for every program or for the one named.
    var tokenReadError: Error?
    var tokenReadErrorProgramId: String?

    /// The distinct hosts that each prove an expiry this scripted node finds, as the failover
    /// client would report them; nil keeps the one unnamed host a single client stands for.
    var expiryWitnesses: Set<String>?

    private(set) var methods: [String] = []
    private(set) var sentTransactions: [String] = []

    func resolveSignature(
        _ signature: String,
        transaction: ParsedSolanaTransaction,
        blockhashContextSlot: Int64?,
        rpcURL: String?
    ) async throws -> SolanaSignatureResolution {
        let resolution = try await resolveSignatureOnOneNode(
            signature, transaction: transaction, blockhashContextSlot: blockhashContextSlot, rpcURL: rpcURL
        )
        if case .expired = resolution, let expiryWitnesses {
            return .expired(provingHosts: expiryWitnesses)
        }
        return resolution
    }

    func latestBlockhash(commitment _: SolanaRpcCommitment, rpcURL _: String?) async throws -> SolanaLatestBlockhashResponse {
        methods.append("getLatestBlockhash")
        return SolanaLatestBlockhashResponse(
            context: SolanaRpcContext(apiVersion: nil, slot: 1),
            value: SolanaLatestBlockhash(blockhash: "7GjNiPun3AzEazTZoFEjZgcBMeuaXdpjHq2raZTmTrfs", lastValidBlockHeight: lastValidBlockHeight)
        )
    }

    func feeForMessage(_: String, commitment _: SolanaRpcCommitment, rpcURL _: String?) async throws -> SolanaFeeForMessageResponse {
        methods.append("getFeeForMessage")
        return SolanaFeeForMessageResponse(context: SolanaRpcContext(apiVersion: nil, slot: 1), value: Self.feeLamports)
    }

    func minimumBalanceForRentExemption(dataLength: Int, commitment _: SolanaRpcCommitment, rpcURL _: String?) async throws -> Int64 {
        methods.append("getMinimumBalanceForRentExemption")
        return dataLength == 0 ? emptyAccountRent : tokenAccountRent
    }

    func accountExists(address: String, commitment _: SolanaRpcCommitment, rpcURL _: String?) async throws -> Bool {
        methods.append("getAccountInfo(exists)")
        return accounts[address] != nil
    }

    func simulateTransaction(_: String, options _: SolanaSimulationOptions, rpcURL _: String?) async throws -> SolanaSimulationResponse {
        methods.append("simulateTransaction")
        return SolanaSimulationResponse(
            context: SolanaRpcContext(apiVersion: nil, slot: 1),
            value: SolanaSimulationValue(errorJSON: nil, logs: [], replacementBlockhash: nil, unitsConsumed: 150)
        )
    }

    func sendRawTransaction(_ transactionBase64: String, options _: SolanaBroadcastOptions, rpcURL _: String?) async throws -> String {
        methods.append("sendTransaction")
        sentTransactions.append(transactionBase64)
        if !sendResults.isEmpty {
            try sendResults.removeFirst().get()
        }
        return try Self.firstSignature(transactionBase64)
    }

    /// The fee payer's signature, which is the transaction's id.
    static func firstSignature(_ transactionBase64: String) throws -> String {
        let transaction = try XCTUnwrap(Data(base64Encoded: transactionBase64))
        let parsed = try SolanaTransactionSigner.parseSerializedTransaction(transaction)
        return base58(Array(transaction.subdata(in: parsed.signaturesOffset ..< parsed.signaturesOffset + 64)))
    }

    static func base58(_ bytes: [UInt8]) -> String {
        let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
        var digits: [Int] = []
        for byte in bytes {
            var carry = Int(byte)
            for index in digits.indices {
                let value = digits[index] * 256 + carry
                digits[index] = value % 58
                carry = value / 58
            }
            while carry > 0 {
                digits.append(carry % 58)
                carry /= 58
            }
        }
        return String(repeating: "1", count: bytes.prefix { $0 == 0 }.count) + String(digits.reversed().map { alphabet[$0] })
    }

    func accountInfo(address: String, commitment _: SolanaRpcCommitment, rpcURL _: String?) async throws -> SolanaAccountInfo? {
        methods.append("getAccountInfo")
        return accounts[address]
    }

    func balance(address: String, commitment _: SolanaRpcCommitment, rpcURL _: String?) async throws -> Int64 {
        methods.append("getBalance")
        if let readError {
            throw readError
        }
        return accounts[address]?.lamports ?? 0
    }

    func tokenAccountsByOwner(owner _: String, programId: String, commitment _: SolanaRpcCommitment, rpcURL _: String?) async throws -> [SolanaParsedTokenAccount] {
        methods.append("getTokenAccountsByOwner(\(programId.prefix(5)))")
        if let readError {
            throw readError
        }
        if let tokenReadError, tokenReadErrorProgramId == nil || tokenReadErrorProgramId == programId {
            throw tokenReadError
        }
        return tokenAccounts[programId] ?? []
    }

    func signatureStatuses(_ signatures: [String], searchTransactionHistory _: Bool, rpcURL _: String?) async throws -> [SolanaSignatureStatus?] {
        methods.append("getSignatureStatuses")
        if let lookupError {
            throw lookupError
        }
        let status = statuses.count > 1 ? statuses.removeFirst() : statuses.first ?? nil
        return signatures.map { _ in status }
    }

    func signatureStatusObservation(_ signature: String, rpcURL: String?) async throws -> SolanaSignatureStatusObservation {
        let status = try await signatureStatuses([signature], searchTransactionHistory: true, rpcURL: rpcURL).first ?? nil
        return SolanaSignatureStatusObservation(context: SolanaRpcContext(apiVersion: nil, slot: 100), status: status)
    }

    func finalizedBlockhash(slot: Int64, rpcURL _: String?) async throws -> String? {
        methods.append("getBlock")
        if let lookupError { throw lookupError }
        XCTAssertEqual(slot, 1)
        return "7GjNiPun3AzEazTZoFEjZgcBMeuaXdpjHq2raZTmTrfs"
    }

    func blockhashValidity(_ blockhash: String, minContextSlot: Int64?, rpcURL _: String?) async throws -> SolanaBlockhashValidity {
        methods.append("isBlockhashValid")
        if let lookupError { throw lookupError }
        XCTAssertEqual(blockhash, "7GjNiPun3AzEazTZoFEjZgcBMeuaXdpjHq2raZTmTrfs")
        return SolanaBlockhashValidity(context: SolanaRpcContext(apiVersion: nil, slot: 100), isValid: blockhashValid)
    }

    func blockHeight(commitment _: SolanaRpcCommitment, rpcURL _: String?) async throws -> Int64 {
        methods.append("getBlockHeight")
        if let lookupError {
            throw lookupError
        }
        return blockHeights.count > 1 ? blockHeights.removeFirst() : blockHeights.first ?? 0
    }

    func recentPrioritizationFees(accounts _: [String], rpcURL _: String?) async throws -> [Int64] {
        methods.append("getRecentPrioritizationFees")
        return [0, 0, 2000]
    }
}

final class ScriptedSolanaBalances: SolanaBalanceSyncing {
    private let nativeLamports: Int64
    private let tokens: [UniversalWalletIndexedAssetBalance]

    init(nativeLamports: Int64, tokens: [UniversalWalletIndexedAssetBalance] = []) {
        self.nativeLamports = nativeLamports
        self.tokens = tokens
    }

    func balances(
        wallet: String,
        network: UniversalWalletRegistry.SolanaNetwork,
        baseURL _: String?,
        includeTokenMetadata _: Bool
    ) async throws -> SolanaBalanceSyncResult {
        let native = UniversalWalletIndexedAssetBalance(
            accountId: network.id,
            ecosystem: .solana,
            chainId: network.chainId,
            assetId: network.nativeAsset.id,
            amount: String(nativeLamports),
            decimals: network.nativeAsset.decimals,
            isNative: true,
            symbol: network.nativeAsset.symbol,
            name: network.name,
            syncedAtMillis: 1
        )
        return SolanaBalanceSyncResult(
            wallet: wallet,
            networkId: network.id,
            chainId: network.chainId,
            syncedAtMillis: 1,
            nativeBalance: native,
            tokenBalances: tokens,
            balances: [native] + tokens
        )
    }
}

struct StaticSolanaMnemonicProvider: UniversalWalletMnemonicProviding {
    let mnemonic: String?

    func mnemonic(for _: MetaAccountModel, chain _: ChainModel) throws -> String? {
        mnemonic
    }
}

/// Time for a broadcaster: waiting moves it, and a test can move it hours ahead.
private final class TestClock {
    private let lock = NSLock()
    private var current = Date(timeIntervalSince1970: 2_000_000_000)

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func advance(_ seconds: TimeInterval) {
        lock.lock()
        current = current.addingTimeInterval(seconds)
        lock.unlock()
    }
}

/// Answers `sendTransaction` per node with a JSON-RPC error code, or accepts it with
/// `signature`; every other method fails, so nothing resolves the signature afterwards.
private final class BroadcastCodeTransport: UniversalWalletHTTPTransport {
    struct Sent: Equatable {
        let url: String
        let transaction: String
        let skipPreflight: Bool
    }

    private let codes: [String: Int]
    private let signature: String
    private let lock = NSLock()
    private var recorded: [Sent] = []

    init(codes: [String: Int], signature: String) {
        self.codes = codes
        self.signature = signature
    }

    var sent: [Sent] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func perform(_ request: URLRequest) async throws -> Data {
        let url = request.url?.absoluteString ?? ""
        let body = try (request.httpBody.flatMap { try JSONSerialization.jsonObject(with: $0) as? [String: Any] }) ?? [:]
        let id = (body["id"] as? NSNumber)?.int64Value ?? 0
        switch body["method"] as? String {
        case "getGenesisHash":
            return Data(#"{"jsonrpc":"2.0","id":\#(id),"result":"\#(UniversalWalletRegistry.solanaMainnet.genesisHash)"}"#.utf8)
        case "sendTransaction":
            let params = body["params"] as? [Any] ?? []
            let options = params.last as? [String: Any] ?? [:]
            lock.lock()
            recorded.append(Sent(
                url: url,
                transaction: params.first as? String ?? "",
                skipPreflight: options["skipPreflight"] as? Bool ?? false
            ))
            lock.unlock()
            if let code = codes[url] {
                return Data(#"{"jsonrpc":"2.0","id":\#(id),"error":{"code":\#(code),"message":"fixture"}}"#.utf8)
            }
            return Data(#"{"jsonrpc":"2.0","id":\#(id),"result":"\#(signature)"}"#.utf8)
        default:
            throw URLError(.cannotConnectToHost)
        }
    }
}

private final class UnwritableSolanaPendingStore: SolanaPendingBroadcastStoring {
    func pending(for _: SolanaPendingBroadcastScope) -> SolanaPendingBroadcast? {
        nil
    }

    func save(_: SolanaPendingBroadcast, for _: SolanaPendingBroadcastScope) throws {
        throw SolanaPendingBroadcastStoreError.notPersisted
    }

    func clear(signature _: String, for _: SolanaPendingBroadcastScope) {}
}

/// Every Solana message a user can see is in each of the eight languages the app ships,
/// keeps the English placeholders, and is what the code shows in that language.
final class SolanaLocalizationCoverageTests: XCTestCase {
    static let shippedLanguages = ["en", "id", "ja", "pt-PT", "ru", "tr", "vi", "zh-Hans"]

    static let solanaKeys = [
        "solana.transfer.recipient_invalid.title", "solana.transfer.recipient_invalid.message",
        "solana.transfer.recipient_token_account.title", "solana.transfer.recipient_token_account.message",
        "solana.transfer.recipient_program.title", "solana.transfer.recipient_program.message",
        "solana.transfer.below_new_account_minimum.title", "solana.transfer.below_new_account_minimum.message",
        "solana.transfer.remainder_below_minimum.title", "solana.transfer.remainder_below_minimum.message",
        "solana.transfer.insufficient_sol.title", "solana.transfer.insufficient_sol.message",
        "solana.transfer.insufficient_token.title", "solana.transfer.insufficient_token.message",
        "solana.transfer.token_balance_split.title", "solana.transfer.token_balance_split.message",
        "solana.transfer.token_program_unsupported.title", "solana.transfer.token_program_unsupported.message",
        "solana.transfer.copy_signature",
        "solana.transfer.unknown.title", "solana.transfer.unknown.message", "solana.transfer.unknown.retry",
        "solana.transfer.prior_unresolved.title", "solana.transfer.prior_unresolved.message",
        "solana.transfer.prior_sent.title", "solana.transfer.prior_sent.message",
        "solana.transfer.prior_not_sent.title", "solana.transfer.prior_not_sent.message",
        "solana.transfer.failed.title", "solana.transfer.failed.message",
        "solana.transfer.not_sent.title", "solana.transfer.not_sent.no_connection",
        "solana.transfer.not_sent.rejected", "solana.transfer.not_sent.expired",
        "solana.transfer.unverified.title", "solana.transfer.unverified.message",
        "solana.transfer.prior_unverified.title", "solana.transfer.prior_unverified.message",
        "solana.transfer.recovery_unavailable.title", "solana.transfer.recovery_unavailable.message",
        "solana.transfer.recovery_unreadable.message",
        "solana.transfer.account_creation.title", "solana.transfer.account_creation.included",
        "send.unavailable.solana_paused.title", "send.unavailable.solana_paused.message",
        "send.unavailable.network.title", "send.unavailable.asset.message",
        "send.unavailable.account.title", "send.unavailable.account.message",
        "send.unavailable.not_prepared.title", "send.unavailable.not_prepared.message",
        "wallet.transaction.history.solana.explorer.message", "wallet.transaction.history.view.explorer"
    ]

    func testEverySolanaMessageIsTranslatedInEveryShippedLanguage() throws {
        let english = try Self.bundle("en")
        for language in Self.shippedLanguages {
            let bundle = try Self.bundle(language)
            for key in Self.solanaKeys {
                let missing = "\u{1}missing"
                let value = bundle.localizedString(forKey: key, value: missing, table: "Localizable")
                let englishValue = english.localizedString(forKey: key, value: missing, table: "Localizable")
                XCTAssertNotEqual(value, missing, "\(language) has no \(key)")
                XCTAssertFalse(value.isEmpty, "\(language): \(key)")
                XCTAssertEqual(Self.placeholders(value), Self.placeholders(englishValue), "\(language): \(key)")
                if language != "en" {
                    XCTAssertNotEqual(value, englishValue, "\(language) still shows English for \(key)")
                }
            }
        }
    }

    func testRefusalsAndPausedSendReadTheSelectedLanguage() throws {
        let refusals: [SolanaTransferRefusal] = [
            .invalidRecipient, .recipientNotWallet, .recipientIsTokenAccount, .recipientIsProgram,
            .amountBelowNewAccountMinimum(minimumLamports: 890_880), .remainderBelowAccountMinimum(minimumLamports: 890_880),
            .insufficientSol, .insufficientTokenBalance, .tokenBalanceSplit, .unsupportedTokenProgram
        ]
        let english = refusals.map { $0.toErrorContent(for: Locale(identifier: "en")).title }
        for language in Self.shippedLanguages {
            let locale = Locale(identifier: language)
            let titles = refusals.map { $0.toErrorContent(for: locale).title }
            XCTAssertEqual(Set(titles).count, titles.count - 1, "\(language): only the two token-account refusals share a title")
            XCTAssertFalse(titles.contains { $0.hasPrefix("solana.") }, language)
            if language != "en" {
                XCTAssertTrue(zip(titles, english).allSatisfy { $0 != $1 }, "\(language): \(titles)")
            }
            XCTAssertTrue(
                SolanaTransferRefusal.unsupportedTokenProgram.toErrorContent(for: locale).message.contains("Token-2022"),
                language
            )
            let paused = SendUnavailableReason.solanaSendPaused
            XCTAssertEqual(
                paused.title(for: locale),
                try Self.bundle(language).localizedString(forKey: "send.unavailable.solana_paused.title", value: nil, table: nil)
            )
        }
        // A region or an unshipped language reads the right table, never the device language.
        XCTAssertEqual(SolanaTransferRefusal.insufficientSol.toErrorContent(for: Locale(identifier: "en_US")).title, "Not enough SOL")
        XCTAssertEqual(
            SolanaTransferRefusal.insufficientSol.toErrorContent(for: Locale(identifier: "pt_PT")).title,
            SolanaTransferRefusal.insufficientSol.toErrorContent(for: Locale(identifier: "pt-PT")).title
        )
        XCTAssertEqual(SolanaTransferRefusal.insufficientSol.toErrorContent(for: Locale(identifier: "ja_JP")).title, "SOL が不足しています")
        XCTAssertEqual(SolanaTransferRefusal.insufficientSol.toErrorContent(for: Locale(identifier: "xx")).title, "Not enough SOL")
    }

    /// Region and script variants read the table iOS would pick for them, and a language the
    /// app does not ship reads English, whatever language the device uses.
    func testLocalesReadTheShippedTableIOSWouldPick() throws {
        let cases: [(String, String)] = [
            ("en", "en"), ("en_US", "en"), ("en-GB", "en"),
            ("ja", "ja"), ("ja_JP", "ja"),
            ("id_ID", "id"), ("in", "id"),
            ("pt_PT", "pt-PT"), ("pt-PT", "pt-PT"), ("pt-BR", "pt-PT"), ("pt_BR", "pt-PT"),
            ("zh-Hans", "zh-Hans"), ("zh-Hans-CN", "zh-Hans"), ("zh_Hans_CN", "zh-Hans"),
            ("zh_CN", "zh-Hans"), ("zh-CN", "zh-Hans"), ("zh-SG", "zh-Hans"),
            ("ru_RU", "ru"), ("tr_TR", "tr"), ("vi_VN", "vi"),
            ("xx", "en"), ("fr_FR", "en")
        ]
        for (identifier, expected) in cases {
            let locale = Locale(identifier: identifier)
            XCTAssertEqual(
                Bundle.localizationBundle(for: locale).bundleURL.deletingPathExtension().lastPathComponent,
                expected,
                identifier
            )
            XCTAssertEqual(
                SolanaTransferRefusal.insufficientSol.toErrorContent(for: locale).title,
                try Self.bundle(expected).localizedString(forKey: "solana.transfer.insufficient_sol.title", value: nil, table: nil),
                identifier
            )
            XCTAssertEqual(
                SendUnavailableReason.solanaSendPaused.title(for: locale),
                try Self.bundle(expected).localizedString(forKey: "send.unavailable.solana_paused.title", value: nil, table: nil),
                identifier
            )
        }
    }

    private static func bundle(_ language: String) throws -> Bundle {
        try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)), language)
    }

    private static func placeholders(_ text: String) -> [String] {
        let pattern = try? NSRegularExpression(pattern: "%(?:\\d+\\$)?[@dfsu]")
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        return (pattern?.matches(in: text, range: range) ?? []).compactMap { Range($0.range, in: text).map { String(text[$0]) } }
    }
}
