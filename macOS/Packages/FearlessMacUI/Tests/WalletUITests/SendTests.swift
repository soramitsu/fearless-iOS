import DesignSystem
import Foundation
import Testing
import WalletCore
@testable import WalletPreviewSupport
@testable import WalletUI

@MainActor
@Suite("Send form")
struct SendFormTests {
    private let recipient = PreviewSampleData.sampleRecipientPolkadot

    @Test func amountsAreParsedExactlyInTheUsersLocale() async throws {
        let fixture = try await Fixture.make()
        let english = fixture.sendModel()
        english.amountText = "1,000.25"
        #expect(english.parsedAmount == amount("1000.25", 10))
        english.amountText = "0.0000000001"
        #expect(english.parsedAmount?.units == "1", "the smallest unit survives")
        english.amountText = "0.00000000001"
        #expect(english.parsedAmount == nil, "more decimals than the asset has is refused, never rounded")
        #expect(english.amountFormatError == "Enter a number with at most 10 decimal places.")
        english.amountText = "abc"
        #expect(english.parsedAmount == nil)
        english.amountText = "-5"
        #expect(english.parsedAmount == nil)

        let german = fixture.sendModel(locale: Locale(identifier: "de_DE"))
        german.amountText = "1,5"
        #expect(german.parsedAmount == amount("1.5", 10))
        german.amountText = "1.000,25"
        #expect(german.parsedAmount == amount("1000.25", 10))
    }

    @Test func stablecoinAmountsKeepSixDecimals() async throws {
        let fixture = try await Fixture.make()
        let model = fixture.sendModel(asset: PreviewCatalog.usdtAssetHub)
        model.amountText = "1.123456"
        #expect(model.parsedAmount?.units == "1123456")
        model.amountText = "1.1234567"
        #expect(model.parsedAmount == nil)
    }

    @Test func fiatEntryConvertsWithoutFloatingPoint() async throws {
        let fixture = try await Fixture.make()
        let model = fixture.sendModel()
        #expect(model.canUseFiat)
        model.toggleAmountUnit()
        #expect(model.amountUnit == .fiat)
        model.amountText = "41.2"
        #expect(model.parsedAmount == amount("10", 10), "41.20 USD at 4.12 USD is exactly 10 DOT")
        #expect(model.convertedAmountText == "≈ 10 DOT")
        model.toggleAmountUnit()
        #expect(model.amountUnit == .asset)
        #expect(model.amountText == "10")

        let testnet = fixture.sendModel(asset: PreviewCatalog.wnd)
        #expect(!testnet.canUseFiat, "an asset without a price can only be entered in its own unit")
        testnet.toggleAmountUnit()
        #expect(testnet.amountUnit == .asset)
    }

    @Test func maxFillsTheEnginesMaximum() async throws {
        let fixture = try await Fixture.make()
        let model = fixture.sendModel()
        await model.setMax()
        // 750.5 transferable − 0.0157 fee − 1 DOT kept as the minimum balance.
        #expect(model.maxSendable == amount("749.4843", 10))
        #expect(model.amountText == "749.4843")
        #expect(model.parsedAmount == model.maxSendable)

        model.keepAlive = false
        await model.prepareNow()
        #expect(model.maxSendable == amount("750.4843", 10), "without keep-alive only the fee is held back")
    }

    @Test func aCompleteDraftCanBeReviewed() async throws {
        let fixture = try await Fixture.make()
        let model = fixture.sendModel()
        #expect(!model.canReview)
        model.recipientText = recipient
        model.amountText = "25"
        await model.prepareNow()
        #expect(model.isRecipientValid)
        #expect(model.issueMessages.isEmpty)
        #expect(model.feeText == "0.0157 DOT")
        #expect(model.canReview)
        await model.review()
        #expect(model.stage == .review)
        #expect(model.preparation?.request.recipient == recipient, "the review shows the whole address")
        model.backToForm()
        #expect(model.stage == .form)
        #expect(model.recipientText == recipient)
        #expect(model.amountText == "25")
    }

    @Test func issuesBecomeMessagesOnTheRightField() async throws {
        let fixture = try await Fixture.make()
        let model = fixture.sendModel()
        model.recipientText = recipient

        model.amountText = "999999"
        await model.prepareNow()
        #expect(model.amountMessage?.text == "You can send at most 750.5 DOT before fees.")
        #expect(!model.canReview)

        model.amountText = "750.5"
        await model.prepareNow()
        #expect(model.amountMessage?.text == "Not enough DOT for the network fee of 0.0157 DOT.")

        model.amountText = "750"
        await model.prepareNow()
        #expect(model.amountMessage?.text.contains("This would leave less than 1 DOT") == true)

        model.amountText = "0"
        await model.prepareNow()
        #expect(model.amountMessage?.text == "Enter an amount greater than zero.")

        let newAccount = PreviewAddressCodec.fakeSubstrateAddress(seed: Data("new account".utf8), prefix: 0)
        model.recipientText = newAccount
        model.amountText = "0.5"
        await model.prepareNow()
        #expect(model.amountMessage?.text.contains("must receive at least 1 DOT") == true)

        model.recipientText = PreviewSampleData.alice.polkadot
        model.amountText = "5"
        await model.prepareNow()
        #expect(model.recipientMessage?.text == "This is your own address on Polkadot. Choose another recipient.")
    }

    @Test func everyIssueHasAPlainSentence() {
        let asset = PreviewCatalog.dot
        let chain = PreviewCatalog.polkadot
        let issues: [(TransferIssue, SendField)] = [
            (.watchOnlyWallet, .general),
            (.unsupportedAsset, .general),
            (.invalidRecipient("Bad address."), .recipient),
            (.invalidRecipient(""), .recipient),
            (.recipientIsSender, .recipient),
            (.amountIsZero, .amount),
            (.insufficientBalance(available: amount("1", 10)), .amount),
            (.insufficientBalanceForFee(fee: amount("0.01", 10)), .amount),
            (.belowExistentialDeposit(minimum: amount("1", 10)), .amount),
            (.wouldReapSender(minimumRemaining: amount("1", 10)), .amount),
            (.network("The node did not answer."), .general),
            (.network(""), .general)
        ]
        for (issue, field) in issues {
            let message = TransferIssueText.message(for: issue, asset: asset, feeSymbol: "DOT", chain: chain, locale: Locale(identifier: "en_US"))
            #expect(message.field == field)
            #expect(!message.text.isEmpty)
            #expect(message.text.hasSuffix(".") || message.text.hasSuffix("”."), "\(message.text)")
        }
        let network = TransferIssueText.message(for: .network(""), asset: asset, feeSymbol: "DOT", chain: chain)
        #expect(network.isRetryable)
        #expect(network.text == "The network did not answer. Try again.")
    }

    @Test func aWrongNetworkAddressIsCalledOut() async throws {
        let fixture = try await Fixture.make()
        let model = fixture.sendModel()
        model.recipientText = PreviewSampleData.sampleRecipientKusama
        model.amountText = "1"
        await model.prepareNow()
        #expect(model.isRecipientWrongNetwork)
        #expect(model.recipientMessage?.text.contains("Kusama address") == true)
        #expect(!model.canReview)
        await model.review()
        #expect(model.stage == .form)

        model.recipientText = PreviewSampleData.sampleRecipientEVM
        await model.prepareNow()
        #expect(model.isRecipientWrongNetwork)
        #expect(model.recipientMessage?.text.contains("Ethereum address") == true)
    }

    @Test func messagesWaitUntilAFieldWasEdited() async throws {
        let fixture = try await Fixture.make()
        let model = fixture.sendModel()
        await model.prepareNow()
        #expect(model.preparation?.issues.isEmpty == false, "the engine objects to the empty draft")
        #expect(model.recipientMessage == nil)
        #expect(model.amountMessage == nil)
        await model.review()
        #expect(model.stage == .form)
    }

    @Test func aNetworkProblemKeepsTheInput() async throws {
        let fixture = try await Fixture.make(PreviewScenario(failingChains: [PreviewCatalog.polkadot.id]))
        let model = fixture.sendModel()
        model.recipientText = recipient
        model.amountText = "12.5"
        await model.prepareNow()
        #expect(model.generalMessages.count == 1)
        #expect(model.generalMessages.first?.isRetryable == true)
        #expect(model.feeText == nil)
        #expect(!model.canReview)
        await model.retry()
        #expect(model.recipientText == recipient)
        #expect(model.amountText == "12.5")
    }

    @Test func changingAssetRevalidatesTheRecipient() async throws {
        let fixture = try await Fixture.make()
        let model = fixture.sendModel()
        model.recipientText = recipient
        model.amountText = "1"
        await model.prepareNow()
        #expect(model.isRecipientValid)
        model.selectAsset(PreviewCatalog.eth.id)
        await model.prepareNow()
        #expect(model.isRecipientWrongNetwork, "a Polkadot address is not valid on Ethereum")
        #expect(!model.isSubstrate)
        #expect(model.rowsByChain.first?.chain.id == PreviewCatalog.polkadot.id)
    }
}

@MainActor
@Suite("Send submission")
struct SendSubmissionTests {
    private func reviewedModel(_ scenario: PreviewScenario = .standard) async throws -> (SendModel, Fixture) {
        let fixture = try await Fixture.make(scenario)
        let model = fixture.sendModel()
        model.recipientText = PreviewSampleData.sampleRecipientPolkadot
        model.amountText = "25"
        await model.review()
        #expect(model.stage == .review)
        return (model, fixture)
    }

    @Test func aSuccessfulTransferLightsEveryStage() async throws {
        let (model, fixture) = try await reviewedModel()
        model.approvalPassword = PreviewWalletServices.samplePassword
        await model.approveWithPassword()
        #expect(model.stage == .progress)
        #expect(model.sealStage == .finalized)
        #expect(model.isFinished)
        #expect(!model.didFail)
        #expect(model.transactionHash != nil)
        #expect(model.explorerURL?.host == "polkadot.subscan.io")
        #expect(model.approvalPassword.isEmpty, "the password is dropped after approval")
        #expect(model.submittedRequest?.amount == amount("25", 10))

        let balance = await fixture.services.balances.balances(of: fixture.wallet.id, assets: [PreviewCatalog.dot.id])
        #expect(try balance[PreviewCatalog.dot.id]?.get().total == amount("1225.4843", 10))
    }

    @Test func stagesFollowTheEnginesReports() async throws {
        let (model, _) = try await reviewedModel()
        #expect(model.sealStage == .idle)
        model.apply(.signed)
        #expect(model.sealStage == .signed)
        model.apply(.broadcast(hash: "0xabc", explorerURL: URL(string: "javascript:alert(1)")))
        #expect(model.sealStage == .sent)
        #expect(model.transactionHash == "0xabc")
        #expect(model.explorerURL == nil, "only web links are opened")
        model.apply(.signed)
        #expect(model.sealStage == .sent, "a stage is never unlit")
        model.apply(.included(blockHash: nil))
        #expect(model.sealStage == .accepted)
        #expect(!model.isFinished)
        model.apply(.finalized)
        #expect(model.sealStage == .finalized)
        #expect(model.isFinished)
    }

    @Test func aFailureAtInclusionIsReported() async throws {
        let (model, _) = try await reviewedModel(.transferFailsAtInclusion)
        model.approvalPassword = PreviewWalletServices.samplePassword
        await model.approveWithPassword()
        #expect(model.stage == .progress)
        #expect(model.didFail)
        #expect(model.sealStage == .sent, "the seal stops at the last stage that happened")
        #expect(model.failureReason?.isEmpty == false)
        #expect(model.transactionHash != nil)
    }

    @Test func anUnconfirmedTransferIsNeitherSuccessNorFailure() async throws {
        let (model, fixture) = try await reviewedModel(.transferOutcomeUnknown)
        model.approvalPassword = PreviewWalletServices.samplePassword
        await model.approveWithPassword()
        #expect(model.stage == .progress)
        #expect(model.isOutcomeUnknown)
        #expect(!model.didFail, "an unknown outcome is not a failure")
        #expect(model.isFinished)
        #expect(model.sealStage == .sent, "only the stages that happened are lit")
        #expect(model.unknownOutcomeReason?.isEmpty == false)
        #expect(model.transactionHash != nil, "the hash stays available to check the explorer")
        #expect(model.explorerURL != nil)

        let history = try await fixture.services.activity.activity(of: fixture.wallet.id, assets: nil)
        #expect(history.items.first?.status == .pending, "the history keeps it pending")
        let balance = await fixture.services.balances.balances(of: fixture.wallet.id, assets: [PreviewCatalog.dot.id])
        #expect(try balance[PreviewCatalog.dot.id]?.get().total == amount("1250.5", 10), "nothing is assumed spent")
    }

    @Test func unknownOutcomeReportsAreKeptApartFromFailures() async throws {
        let (model, _) = try await reviewedModel()
        model.apply(.signed)
        model.apply(.broadcast(hash: "0xabc", explorerURL: URL(string: "https://example.org/tx/0xabc")))
        model.apply(.outcomeUnknown(reason: ""))
        #expect(model.isOutcomeUnknown)
        #expect(model.unknownOutcomeReason == "The transfer was sent, but its confirmation did not arrive.")
        #expect(!model.didFail)
        #expect(model.failureReason == nil)

        // A definitive failure wins over "unknown"; a late finality report clears the doubt.
        let (failed, _) = try await reviewedModel()
        failed.apply(.outcomeUnknown(reason: "Lost the node."))
        failed.apply(.failed(reason: "Rejected."))
        #expect(failed.didFail)
        #expect(!failed.isOutcomeUnknown)

        let (finalized, _) = try await reviewedModel()
        finalized.apply(.outcomeUnknown(reason: "Lost the node."))
        finalized.apply(.finalized)
        #expect(!finalized.isOutcomeUnknown)
        #expect(finalized.sealStage == .finalized)
    }

    @Test func aWrongPasswordStaysOnTheReview() async throws {
        let (model, _) = try await reviewedModel()
        model.approvalPassword = "not the password"
        await model.approveWithPassword()
        #expect(model.stage == .review)
        #expect(model.approvalError == WalletError.wrongPassword.errorDescription)
        #expect(model.approvalPassword.isEmpty)
        #expect(model.recipientText == PreviewSampleData.sampleRecipientPolkadot)
        #expect(model.amountText == "25")
        #expect(!model.isSubmitting)
    }

    @Test func aSecondApprovalWhileSubmittingIsIgnored() async throws {
        let (model, fixture) = try await reviewedModel()
        let before = try await fixture.services.activity.activity(of: fixture.wallet.id, assets: nil).items.count
        model.approvalPassword = PreviewWalletServices.samplePassword
        async let first: Void = model.approveWithPassword()
        async let second: Void = model.approveWithPassword()
        _ = await (first, second)
        let after = try await fixture.services.activity.activity(of: fixture.wallet.id, assets: nil).items.count
        #expect(after == before + 1, "one approval, one transfer")
        #expect(model.sealStage == .finalized)
    }

    @Test func touchIDApprovalNeedsItEnabled() async throws {
        let (model, _) = try await reviewedModel()
        #expect(!model.canApproveWithBiometrics)
        await model.approveWithBiometrics()
        #expect(model.stage == .review)

        let (enabled, _) = try await reviewedModel(PreviewScenario(biometrics: .enabled))
        #expect(enabled.canApproveWithBiometrics)
        await enabled.approveWithBiometrics()
        #expect(enabled.sealStage == .finalized)
    }

    @Test func watchOnlyWalletsCannotSend() async throws {
        let fixture = try await Fixture.make(walletID: PreviewSampleData.watchWalletID)
        let model = fixture.sendModel()
        model.recipientText = PreviewSampleData.bob.polkadot
        model.amountText = "1"
        await model.prepareNow()
        #expect(model.generalMessages.contains { $0.text.contains("watch-only") })
        #expect(!model.canReview)
    }
}

@MainActor
@Suite("Receive")
struct ReceiveTests {
    @Test func loadsTheAddressOfTheChosenNetwork() async throws {
        let fixture = try await Fixture.make()
        let chains = fixture.store.chains(for: fixture.wallet, includeTestnets: false)
        let model = ReceiveModel(wallet: fixture.wallet, chains: chains, assets: fixture.store.assets, initialChainID: nil, services: fixture.services)
        #expect(model.state == .loading)
        #expect(model.chain?.id == PreviewCatalog.polkadot.id)
        await model.load()
        #expect(model.address == PreviewSampleData.alice.polkadot)
        #expect(model.explorerURL?.absoluteString == "https://polkadot.subscan.io/account/\(PreviewSampleData.alice.polkadot)")
        #expect(model.warning == "Send only DOT on the Polkadot network to this address. Anything sent from another network may be lost.")

        await model.select(PreviewCatalog.kusama.id)
        #expect(model.address == PreviewSampleData.alice.kusama)

        await model.select(PreviewCatalog.polkadotAssetHub.id)
        #expect(model.warning.hasPrefix("Send only DOT, USDT and USDC on the Polkadot Asset Hub network"))

        await model.select(PreviewCatalog.ethereum.id)
        #expect(model.address == PreviewSampleData.evmAccount0)
    }

    @Test func prefersTheRequestedNetworkAndHidesTestnetsUnlessAsked() async throws {
        let fixture = try await Fixture.make()
        let mainnets = fixture.store.chains(for: fixture.wallet, includeTestnets: false)
        #expect(!mainnets.contains { $0.isTestnet })
        let all = fixture.store.chains(for: fixture.wallet, includeTestnets: true)
        #expect(all.contains { $0.id == PreviewCatalog.westend.id })
        let model = ReceiveModel(wallet: fixture.wallet, chains: all, assets: fixture.store.assets, initialChainID: PreviewCatalog.westend.id, services: fixture.services)
        await model.load()
        #expect(model.address == PreviewSampleData.alice.generic)
    }

    @Test func aWatchOnlyWalletOnlyOffersItsOwnEcosystem() async throws {
        let fixture = try await Fixture.make(walletID: PreviewSampleData.watchWalletID)
        let chains = fixture.store.chains(for: fixture.wallet, includeTestnets: true)
        #expect(chains.allSatisfy { $0.ecosystem == .substrate })
        let model = ReceiveModel(wallet: fixture.wallet, chains: [], assets: [], initialChainID: nil, services: fixture.services)
        await model.load()
        #expect(model.address == nil)
        if case .failed = model.state {} else { Issue.record("an empty network list must be reported") }
    }
}
