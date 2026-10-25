import XCTest
import CoreData
import UIKit
import BigInt
import RobinHood
import SoraFoundation
import SSFModels
import SSFUtils
#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
#endif
@testable import fearless

/// Send used to swallow every error thrown while preparing dependencies, leaving universal
/// TON, Iroha and any paused network on a screen that never loads a fee. Routing errors now
/// reach the presenter, which explains them and always offers a next step.
final class SendDependencyErrorSurfacingTests: XCTestCase {
    /// The copy assertions are written in English, and the Solana and Send messages are
    /// translated. Pin the app language so they hold on a simulator set to another language;
    /// a test that needs another language sets it and restores this one.
    private var languageBeforeTest: String?

    override func setUp() {
        super.setUp()
        languageBeforeTest = LocalizationManager.shared.selectedLocalization
        LocalizationManager.shared.selectedLocalization = "en"
    }

    override func tearDown() {
        if let languageBeforeTest {
            LocalizationManager.shared.selectedLocalization = languageBeforeTest
        }
        super.tearDown()
    }

    // MARK: - Interactor

    func testUpdateDependencies_whenRoutingThrows_thenOutputReceivesErrorOnMainThread() throws {
        let cases: [(ChainAsset, SendDepencyContainer, UniversalWalletSendRoutingError)] = try [
            (
                ChainAsset(chain: Self.tonChain, asset: Self.tonAsset),
                Self.productionContainer(),
                .tonProductionSendDisabled
            ),
            (
                ChainAsset(
                    chain: UniversalWalletRegistry.tairaChainModel,
                    asset: XCTUnwrap(UniversalWalletRegistry.tairaChainModel.assets.first)
                ),
                Self.productionContainer(),
                .irohaProductionSendDisabled
            ),
            (
                ChainAsset(chain: Self.bitcoinChain, asset: Self.btcAsset),
                Self.productionContainer(),
                .bitcoinSendPaused
            )
        ]
        MultiChainFeaturePolicy.update(Self.bitcoinVeto)
        defer { MultiChainFeaturePolicy.liftRememberedVetoes() }

        for (chainAsset, container, expectedError) in cases {
            let output = SendInteractorOutputSpy()
            output.errorExpectation = expectation(description: "dependency error for \(chainAsset.chain.chainId)")
            let interactor = Self.makeInteractor(container: container)
            interactor.setup(with: output)

            interactor.updateSubscriptions(for: chainAsset)
            try wait(for: [XCTUnwrap(output.errorExpectation)], timeout: 5)

            XCTAssertEqual(output.receivedErrors.count, 1)
            XCTAssertEqual(output.receivedErrors.first?.0 as? UniversalWalletSendRoutingError, expectedError)
            XCTAssertEqual(output.receivedErrors.first?.1, chainAsset)
            XCTAssertEqual(output.receivedOnMainThread, [true])
            XCTAssertEqual(output.dependenciesReceivedCount, 0)
        }
    }

    @MainActor
    func testLateDependencyFailureCannotOverwriteNewNetwork() async throws {
        let firstStarted = expectation(description: "first preparation suspended")
        let secondStarted = expectation(description: "second preparation suspended")
        var first: CheckedContinuation<SendDependencies, Error>?
        var second: CheckedContinuation<SendDependencies, Error>?
        let interactor = Self.makeInteractor(container: Self.productionContainer(), prepareDependencies: { asset in
            try await withCheckedThrowingContinuation { continuation in
                if asset.chain.chainId == Self.bitcoinChain.chainId { first = continuation; firstStarted.fulfill() }
                else { second = continuation; secondStarted.fulfill() }
            }
        })
        let spy = SendInteractorOutputSpy()
        interactor.setup(with: spy)
        interactor.updateSubscriptions(for: ChainAsset(chain: Self.bitcoinChain, asset: Self.btcAsset))
        await fulfillment(of: [firstStarted], timeout: 2)
        interactor.updateSubscriptions(for: ChainAsset(chain: Self.solanaChain, asset: Self.solAsset))
        await fulfillment(of: [secondStarted], timeout: 2)
        let currentDelivered = expectation(description: "current error delivered")
        spy.errorExpectation = currentDelivered
        try XCTUnwrap(second).resume(throwing: TransferServiceError.solanaSendPaused)
        await fulfillment(of: [currentDelivered], timeout: 2)
        spy.errorExpectation = nil
        try XCTUnwrap(first).resume(throwing: UniversalWalletSendRoutingError.bitcoinSendPaused)
        await Task.yield()
        let drained = expectation(description: "late callback drained")
        DispatchQueue.main.async { drained.fulfill() }
        await fulfillment(of: [drained], timeout: 2)
        XCTAssertEqual(spy.receivedErrors.count, 1)
        XCTAssertEqual(spy.receivedErrors.first?.1.chain.chainId, Self.solanaChain.chainId)
        XCTAssertEqual(spy.receivedOnMainThread, [true])
    }

    func testAssetPickerPreservesExactIdentityWhenSymbolsCollideAndClearsAmount() {
        let original = ChainAsset(chain: Self.bitcoinChain, asset: Self.btcAsset)
        let selected = ChainAsset(chain: Self.bitcoinChain, asset: AssetModel(id: "different-btc", name: "Other asset", symbol: "BTC", precision: 2, isUtility: false, isNative: false))
        let context = makePresenter(chainAsset: original)
        context.presenter.updateAmount(9)
        context.presenter.didSwitchSendAll(true)
        context.presenter.assetSelection(didCompleteWith: selected, contextTag: nil)
        XCTAssertEqual(context.interactor.updatedChainAssets.last?.assetKey, selected.assetKey)
        XCTAssertEqual(context.view.sendAllStates.last, false)
        let flushed = expectation(description: "input model rendered")
        DispatchQueue.main.async { flushed.fulfill() }
        wait(for: [flushed], timeout: 2)
        XCTAssertNil(context.view.amountInputs.last?.decimalAmount)
        XCTAssertEqual(context.router.dismissCount, 0)
    }

    func testDelayedNetworkPickerResultCannotSwitchNewlySelectedAsset() throws {
        let assets = try SendNetworkFixture.assets()
        let usdt = try XCTUnwrap(assets.first { $0.chain.name == "Ethereum" && $0.asset.symbol.lowercased() == "usdt" })
        let context = makePresenter(chainAsset: usdt)
        context.interactor.deferNetworks = true
        context.presenter.didTapSelectNetwork()
        let pending = try XCTUnwrap(context.interactor.pendingNetworks)
        context.presenter.assetSelection(didCompleteWith: ChainAsset(chain: Self.solanaChain, asset: Self.solAsset), contextTag: nil)
        pending([usdt.chain, Self.solanaChain])
        XCTAssertEqual(context.router.networkPickers, 0)
        context.presenter.assetSelection(didCompleteWith: usdt, contextTag: nil)
        pending([usdt.chain, Self.solanaChain])
        XCTAssertEqual(context.router.networkPickers, 0, "switching back must not revive an old picker request")
    }

    // MARK: - Presenter

    @MainActor
    func testConversionQuoteCannotReturnAfterSelectingAwayAndBack() async throws {
        let chain = try XCTUnwrap(SendNetworkFixture.assets().first { $0.chain.name == "Ethereum" }?.chain)
        let asset = ChainAsset(chain: chain, asset: AssetModel(id: "fixture-bokolo", name: "Fixture", symbol: "FIX", precision: 0, currencyId: BokoloConstants.bokoloCashAssetCurrencyId, isUtility: true, isNative: false))
        chain.assets.insert(asset.asset)
        XCTAssertTrue(asset.isUtility)
        let context = makePresenter(chainAsset: asset)
        let started = expectation(description: "old conversion suspended")
        var pending: CheckedContinuation<SwapValues?, Error>?
        context.interactor.convertAction = {
            try await withCheckedThrowingContinuation { pending = $0; started.fulfill() }
        }
        context.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: 0)), for: asset)
        context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 1)))
        await fulfillment(of: [started], timeout: 2)
        context.presenter.assetSelection(didCompleteWith: ChainAsset(chain: Self.solanaChain, asset: Self.solAsset), contextTag: nil)
        context.presenter.assetSelection(didCompleteWith: asset, contextTag: nil)
        try XCTUnwrap(pending).resume(returning: SwapValues(dexId: 0, amount: "91", rewards: []))
        let drained = expectation(description: "old conversion finished")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { drained.fulfill() }
        await fulfillment(of: [drained], timeout: 2)
        XCTAssertTrue(context.view.feeModels.compactMap { $0 }.isEmpty)
    }

    @MainActor
    func testConversionQuoteOnlyPublishesLatestRequestEvenWhenFeeReturnsToOldValue() async throws {
        let chain = try XCTUnwrap(SendNetworkFixture.assets().first { $0.chain.name == "Ethereum" }?.chain)
        let asset = ChainAsset(chain: chain, asset: AssetModel(id: "fixture-bokolo", name: "Fixture", symbol: "FIX", precision: 0, currencyId: BokoloConstants.bokoloCashAssetCurrencyId, isUtility: true, isNative: false))
        chain.assets.insert(asset.asset)
        XCTAssertTrue(asset.isUtility)
        let context = makePresenter(chainAsset: asset)
        var pending: [CheckedContinuation<SwapValues?, Error>] = []
        var started = expectation(description: "first quote")
        context.interactor.convertAction = {
            try await withCheckedThrowingContinuation { pending.append($0); started.fulfill() }
        }
        context.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: 0)), for: asset)
        context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 1)))
        await fulfillment(of: [started], timeout: 2)
        started = expectation(description: "second quote")
        context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 2)))
        await fulfillment(of: [started], timeout: 2)
        started = expectation(description: "third quote with original fee")
        context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 1)))
        await fulfillment(of: [started], timeout: 2)
        guard pending.count == 3 else {
            pending.forEach { $0.resume(returning: nil) }
            XCTFail("Expected three suspended conversion requests")
            return
        }
        pending[2].resume(returning: SwapValues(dexId: 0, amount: "3", rewards: []))
        pending[0].resume(returning: SwapValues(dexId: 0, amount: "91", rewards: []))
        pending[1].resume(returning: SwapValues(dexId: 0, amount: "92", rewards: []))
        let drained = expectation(description: "quotes finished")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { drained.fulfill() }
        await fulfillment(of: [drained], timeout: 2)
        let delivered = context.view.feeModels.compactMap { $0 }
        XCTAssertEqual(delivered.count, 1)
        XCTAssertTrue(delivered.first?.amount.contains("3") == true)
    }

    func testPresenter_whenBitcoinPaused_thenShowsSheetWithReceiveAction() throws {
        let previousLanguage = LocalizationManager.shared.selectedLocalization
        LocalizationManager.shared.selectedLocalization = "zh-Hans"
        defer { LocalizationManager.shared.selectedLocalization = previousLanguage }
        let context = makePresenter(chainAsset: ChainAsset(chain: Self.bitcoinChain, asset: Self.btcAsset))

        context.presenter.didReceiveDependenciesError(
            UniversalWalletSendRoutingError.bitcoinSendPaused,
            for: context.chainAsset
        )

        let sheet = try XCTUnwrap(context.router.presentedSheets.first)
        XCTAssertEqual(context.router.presentedSheets.count, 1)
        XCTAssertEqual(sheet.title, "Bitcoin sending is paused right now")
        XCTAssertEqual(sheet.actions.first?.title, R.string.localizable.commonActionReceive(preferredLanguages: ["zh-Hans"]))
        XCTAssertNotNil(sheet.closeAction)
        XCTAssertNotNil(sheet.dismissCompletion)

        sheet.actions.first?.handler?()
        sheet.dismissCompletion?()

        XCTAssertEqual(context.router.receiveChainAssets, [context.chainAsset])
        XCTAssertEqual(context.router.dismissCount, 0)
    }

    func testPresenter_whenPausedSheetIsClosed_thenSendFlowCloses() throws {
        let context = makePresenter(chainAsset: ChainAsset(chain: Self.solanaChain, asset: Self.solAsset))

        context.presenter.didReceiveDependenciesError(TransferServiceError.solanaSendPaused, for: context.chainAsset)
        let sheet = try XCTUnwrap(context.router.presentedSheets.first)
        sheet.dismissCompletion?()

        XCTAssertEqual(sheet.title, "Solana sending is paused right now")
        XCTAssertEqual(context.router.dismissCount, 1)
        XCTAssertTrue(context.router.receiveChainAssets.isEmpty)
    }

    func testPresenter_whenUnknownPreparationFailure_thenOffersRetryThatReroutes() throws {
        let previousLanguage = LocalizationManager.shared.selectedLocalization
        LocalizationManager.shared.selectedLocalization = "zh-Hans"
        defer { LocalizationManager.shared.selectedLocalization = previousLanguage }
        let context = makePresenter(chainAsset: ChainAsset(chain: Self.bitcoinChain, asset: Self.btcAsset))
        let routedBeforeError = context.interactor.updatedChainAssets.count

        context.presenter.didReceiveDependenciesError(ChainRegistryError.connectionUnavailable, for: context.chainAsset)
        let sheet = try XCTUnwrap(context.router.presentedSheets.first)
        sheet.actions.first?.handler?()
        sheet.dismissCompletion?()

        // The message is shown in the app's language, not left in English.
        XCTAssertEqual(sheet.title, "无法准备此转账")
        XCTAssertEqual(
            sheet.title,
            SendUnavailableReason.notPrepared(networkName: Self.bitcoinChain.name).title(for: Locale(identifier: "zh-Hans"))
        )
        XCTAssertEqual(sheet.actions.map(\.title), [R.string.localizable.commonRetry(preferredLanguages: ["zh-Hans"])])
        XCTAssertEqual(context.interactor.updatedChainAssets.count, routedBeforeError + 1)
        XCTAssertEqual(context.router.dismissCount, 0)

        // After a retry a new failure is explained again instead of being swallowed.
        context.presenter.didReceiveDependenciesError(ChainRegistryError.connectionUnavailable, for: context.chainAsset)
        XCTAssertEqual(context.router.presentedSheets.count, 2)
    }

    func testPresenter_whenErrorRepeatsWhileSheetIsShown_thenPresentsOnce() {
        let context = makePresenter(chainAsset: ChainAsset(chain: Self.bitcoinChain, asset: Self.btcAsset))

        for _ in 0 ..< 3 {
            context.presenter.didReceiveDependenciesError(
                UniversalWalletSendRoutingError.bitcoinSendPaused,
                for: context.chainAsset
            )
        }

        XCTAssertEqual(context.router.presentedSheets.count, 1)
    }

    func testPresenter_whenErrorBelongsToNetworkTheUserLeft_thenItIsIgnored() {
        let context = makePresenter(chainAsset: ChainAsset(chain: Self.bitcoinChain, asset: Self.btcAsset))

        context.presenter.didReceiveDependenciesError(
            UniversalWalletSendRoutingError.solanaSendPaused,
            for: ChainAsset(chain: Self.solanaChain, asset: Self.solAsset)
        )

        XCTAssertTrue(context.router.presentedSheets.isEmpty)
    }

    func testUnavailableReasons_whenMapped_thenEachHasTruthfulCopyAndANextStep() {
        let chain = Self.bitcoinChain
        let reasons: [(Error, SendUnavailableReason)] = [
            (UniversalWalletSendRoutingError.bitcoinSendPaused, .bitcoinSendPaused),
            (TransferServiceError.bitcoinSendPaused, .bitcoinSendPaused),
            (UniversalWalletSendRoutingError.solanaSendPaused, .solanaSendPaused),
            (UniversalWalletSendRoutingError.tonProductionSendDisabled, .tonWalletSendUnavailable),
            (TransferServiceError.tonProductionSendDisabled, .tonWalletSendUnavailable),
            (UniversalWalletSendRoutingError.irohaProductionSendDisabled, .irohaSendUnavailable(networkName: chain.name)),
            (UniversalWalletSendRoutingError.unsupported(chainId: "x"), .assetUnsupported(networkName: chain.name)),
            (ChainAccountFetchingError.accountNotExists, .accountMissing(networkName: chain.name)),
            (ChainRegistryError.runtimeMetadaUnavailable, .notPrepared(networkName: chain.name))
        ]
        let locale = Locale(identifier: "en")

        for (error, expected) in reasons {
            let reason = SendUnavailableReason(dependenciesError: error, chain: chain)

            XCTAssertEqual(reason, expected, "\(error)")
            XCTAssertFalse(reason.title(for: locale).isEmpty)
            XCTAssertFalse(reason.message(for: locale).isEmpty)
            XCTAssertFalse(reason.message(for: locale).localizedCaseInsensitiveContains("safe"), "\(reason)")
            XCTAssertFalse(reason.message(for: locale).localizedCaseInsensitiveContains("reinstall"), "\(reason)")
        }

        // Only refusals that a later step can hit map from transfer errors; ordinary transfer
        // failures keep their existing handling on the confirm screen.
        XCTAssertNil(SendUnavailableReason(transferError: TransferServiceError.transferFailed(reason: "x")))
        XCTAssertNil(SendUnavailableReason(transferError: ChainAccountFetchingError.accountNotExists))
        XCTAssertEqual(SendUnavailableReason(transferError: TransferServiceError.solanaSendPaused), .solanaSendPaused)
    }

    // MARK: - Confirm screen

    func testConfirm_whenVetoArrivesAtSubmit_thenShowsPausedSheetInsteadOfGenericFailure() throws {
        let context = makeConfirmPresenter()

        context.presenter.didTransfer(result: .failure(TransferServiceError.bitcoinSendPaused))

        let sheet = try XCTUnwrap(context.wireframe.presentedSheets.first)
        XCTAssertEqual(context.wireframe.presentedSheets.count, 1)
        XCTAssertEqual(sheet.title, "Bitcoin sending is paused right now")
        XCTAssertEqual(context.wireframe.extrinsicFailedCount, 0)

        sheet.actions.first?.handler?()
        sheet.dismissCompletion?()
        XCTAssertEqual(context.wireframe.receiveChainAssets, [context.chainAsset])
        XCTAssertEqual(context.wireframe.finishCount, 0)
    }

    func testConfirm_whenRoutingVetoAppearsAtFeeAndSubmit_thenPresentsOnceAndCloseLeavesFlow() throws {
        let context = makeConfirmPresenter()

        context.presenter.didReceiveFee(result: .failure(UniversalWalletSendRoutingError.bitcoinSendPaused))
        context.presenter.didTransfer(result: .failure(UniversalWalletSendRoutingError.bitcoinSendPaused))

        let sheet = try XCTUnwrap(context.wireframe.presentedSheets.first)
        XCTAssertEqual(context.wireframe.presentedSheets.count, 1)
        sheet.dismissCompletion?()
        XCTAssertEqual(context.wireframe.finishCount, 1)
        XCTAssertTrue(context.wireframe.receiveChainAssets.isEmpty)
    }

    func testConfirm_whenOrdinaryTransferFails_thenKeepsExistingFailureHandling() {
        let context = makeConfirmPresenter()

        context.presenter.didTransfer(result: .failure(TransferServiceError.transferFailed(reason: "rejected")))

        XCTAssertTrue(context.wireframe.presentedSheets.isEmpty)
        XCTAssertEqual(context.wireframe.extrinsicFailedCount, 1)
    }

    // MARK: - Bitcoin transfers whose outcome is unknown (IOSUX-3 B1)

    func testBitcoinUnknownOutcomeSheetOffersCopyAndSameHexRetry() throws {
        let context = makeConfirmPresenter()
        let txid = String(repeating: "ab", count: 32)

        context.presenter.didTransfer(result: .failure(TransferServiceError.bitcoinBroadcastOutcomeUnknown(txid: txid)))

        let sheet = try XCTUnwrap(context.wireframe.presentedSheets.first)
        XCTAssertEqual(context.wireframe.presentedSheets.count, 1)
        XCTAssertEqual(context.wireframe.extrinsicFailedCount, 0, "Never the generic \"failed\" message")
        XCTAssertEqual(sheet.title, "Transfer status is unknown")
        XCTAssertTrue(sheet.message?.contains("Don't send it again") == true)
        XCTAssertTrue(sheet.message?.contains(txid) == true)
        XCTAssertEqual(sheet.actions.map(\.title), ["Retry sending", "Copy transaction ID"])

        sheet.actions[1].handler?()
        XCTAssertEqual(UIPasteboard.general.string, txid)

        sheet.actions[0].handler?()
        sheet.dismissCompletion?()
        // Retry hands back the stored transaction; nothing is planned or signed again.
        XCTAssertEqual(context.interactor.retriedHashes, [txid])
        XCTAssertEqual(context.interactor.refreshFeeCount, 0)
    }

    func testBitcoinUnknownOutcomeSheet_whenClosed_thenNothingIsRetried() throws {
        let context = makeConfirmPresenter()

        context.presenter.didTransfer(
            result: .failure(TransferServiceError.bitcoinBroadcastOutcomeUnknown(txid: String(repeating: "cd", count: 32)))
        )
        try XCTUnwrap(context.wireframe.presentedSheets.first).dismissCompletion?()

        XCTAssertTrue(context.interactor.retriedHashes.isEmpty)
    }

    func testBitcoinPriorTransferUnresolvedOffersRetryOrConflictingReplacement() throws {
        let context = makeConfirmPresenter()
        let txid = String(repeating: "ef", count: 32)

        context.presenter.didTransfer(result: .failure(TransferServiceError.bitcoinPriorTransferUnresolved(txid: txid)))

        let sheet = try XCTUnwrap(context.wireframe.presentedSheets.first)
        XCTAssertEqual(sheet.title, "An earlier transfer is unresolved")
        XCTAssertEqual(
            sheet.actions.map(\.title),
            ["Retry the earlier transfer", "Replace it with this transfer", "Copy transaction ID"]
        )

        sheet.actions[1].handler?()
        sheet.dismissCompletion?()
        XCTAssertEqual(context.interactor.replacementRequests, [txid])
        // The replacement spends the earlier coins, so its fee is quoted again before Confirm.
        XCTAssertEqual(context.interactor.refreshFeeCount, 1)
        XCTAssertTrue(context.interactor.retriedHashes.isEmpty)
    }

    func testBitcoinPriorTransferSentIsReportedAndTheFeeRequoted() throws {
        let context = makeConfirmPresenter()
        let txid = String(repeating: "12", count: 32)

        context.presenter.didTransfer(result: .failure(TransferServiceError.bitcoinPriorTransferConfirmed(txid: txid)))

        let sheet = try XCTUnwrap(context.wireframe.presentedSheets.first)
        XCTAssertEqual(sheet.title, "Your earlier transfer was sent")
        sheet.dismissCompletion?()
        XCTAssertEqual(context.interactor.refreshFeeCount, 1)
        XCTAssertTrue(context.interactor.retriedHashes.isEmpty)
        XCTAssertTrue(context.interactor.replacementRequests.isEmpty)
    }

    func testBitcoinTransferNotSentSaysSoAndOffersATryAgain() throws {
        for reason in [BitcoinTransferNotSentReason.noConnection, .rejectedByNetwork, .coinsAlreadySpent] {
            let context = makeConfirmPresenter()

            context.presenter.didTransfer(result: .failure(TransferServiceError.bitcoinTransferNotSent(reason)))

            let sheet = try XCTUnwrap(context.wireframe.presentedSheets.first)
            XCTAssertEqual(sheet.title, "This transfer wasn't sent")
            XCTAssertFalse(sheet.message?.isEmpty ?? true)
            sheet.dismissCompletion?()
            XCTAssertEqual(context.interactor.refreshFeeCount, 1, "\(reason)")
        }
    }

    /// Only a well-formed transaction ID is ever shown or copied, so an odd value from a
    /// service can never dress up the recovery sheet.
    func testBitcoinRecoverySheetsRefuseMalformedTransactionIds() {
        for txid in ["", "ab", String(repeating: "AB", count: 32), String(repeating: "zz", count: 32), "\u{202E}" + String(repeating: "ab", count: 32)] {
            let context = makeConfirmPresenter()

            context.presenter.didTransfer(result: .failure(TransferServiceError.bitcoinBroadcastOutcomeUnknown(txid: txid)))

            XCTAssertTrue(context.wireframe.presentedSheets.isEmpty, txid)
            XCTAssertEqual(context.wireframe.extrinsicFailedCount, 1, txid)
        }
    }

    // MARK: - Solana transfers (IOSUX-4)

    func testSolanaUnknownOutcomeSheetOffersCopyAndSameTransactionRetry() throws {
        let context = makeSolanaConfirmPresenter()

        context.presenter.didTransfer(result: .failure(TransferServiceError.solanaBroadcastOutcomeUnknown(signature: Self.solanaSignature)))

        let sheet = try XCTUnwrap(context.wireframe.presentedSheets.first)
        XCTAssertEqual(context.wireframe.presentedSheets.count, 1)
        XCTAssertEqual(context.wireframe.extrinsicFailedCount, 0, "Never the generic \"failed\" message")
        XCTAssertEqual(sheet.title, "Transfer status is unknown")
        XCTAssertTrue(sheet.message?.contains("can't pay twice") == true)
        XCTAssertTrue(sheet.message?.contains(Self.solanaSignature) == true)
        XCTAssertEqual(sheet.actions.map(\.title), ["Retry sending", "Copy transaction ID"])

        sheet.actions[1].handler?()
        XCTAssertEqual(UIPasteboard.general.string, Self.solanaSignature)
        sheet.actions[0].handler?()
        sheet.dismissCompletion?()
        XCTAssertEqual(context.interactor.retriedHashes, [Self.solanaSignature])
        XCTAssertEqual(context.interactor.refreshFeeCount, 0, "Retry re-sends the signed transaction; nothing is quoted or signed")
    }

    func testSolanaUnboundRecoveryOffersOnlyCopyAndCloseWithoutRetryOrExpiryPromise() throws {
        let previousLanguage = LocalizationManager.shared.selectedLocalization
        LocalizationManager.shared.selectedLocalization = "en"
        defer { LocalizationManager.shared.selectedLocalization = previousLanguage }
        let context = makeSolanaConfirmPresenter()
        context.presenter.didTransfer(result: .failure(TransferServiceError.solanaRecoveryUnavailable(signature: Self.solanaSignature)))
        let sheet = try XCTUnwrap(context.wireframe.presentedSheets.first)
        XCTAssertEqual(sheet.title, "Saved transfer needs review")
        XCTAssertTrue(sheet.message?.contains("cannot be verified") == true)
        XCTAssertTrue(sheet.message?.contains("Status checks and retry are unavailable") == true)
        XCTAssertFalse(sheet.message?.contains("two minutes") == true)
        XCTAssertTrue(sheet.message?.contains(Self.solanaSignature) == true)
        XCTAssertEqual(sheet.actions.map(\.title), ["Copy ID"])
        sheet.actions[0].handler?()
        XCTAssertEqual(UIPasteboard.general.string, Self.solanaSignature)
        sheet.dismissCompletion?()
        XCTAssertTrue(context.interactor.retriedHashes.isEmpty)
        XCTAssertEqual(context.interactor.refreshFeeCount, 1)
    }

    @MainActor
    func testSolanaUnboundRecoveryActualSheetAllLocalesNormalAndAX5Controls() async throws {
        let previousLanguage = LocalizationManager.shared.selectedLocalization
        defer { LocalizationManager.shared.selectedLocalization = previousLanguage }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let languages = ["en", "ru", "ja", "zh-Hans", "id", "vi", "tr", "pt-PT"]
        XCTAssertEqual(Set(Bundle.main.localizations.filter { $0 != "Base" }), Set(languages))
        for language in languages {
            LocalizationManager.shared.selectedLocalization = language
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let context = makeSolanaConfirmPresenter()
                context.presenter.didTransfer(result: .failure(TransferServiceError.solanaRecoveryUnavailable(signature: Self.solanaSignature)))
                let model = try XCTUnwrap(context.wireframe.presentedSheets.first)
                XCTAssertTrue(model.scrollableContent)
                let bundle = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)))
                let title = bundle.localizedString(forKey: "solana.transfer.recovery_unavailable.title", value: nil, table: nil)
                let message = bundle.localizedString(forKey: "solana.transfer.recovery_unavailable.message", value: nil, table: nil)
                XCTAssertFalse(title.hasPrefix("solana.transfer."))
                XCTAssertEqual(model.title, title)
                XCTAssertEqual(model.actions.map(\.title), [bundle.localizedString(forKey: "wallet.transaction.detail.copy.id", value: nil, table: nil)])
                XCTAssertEqual(model.closeAction, bundle.localizedString(forKey: "common.close", value: nil, table: nil))
                XCTAssertEqual(model.message, String(format: message, locale: Locale(identifier: language), Self.solanaSignature))
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
                window.overrideUserInterfaceStyle = .dark
                if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
                let host = UIViewController()
                window.rootViewController = host
                window.makeKeyAndVisible()
                defer { window.isHidden = true; window.rootViewController = nil }
                let sheet = SheetAletViewController(viewModel: model)
                sheet.modalPresentationStyle = .custom
                sheet.modalTransitioningFactory = ModalSheetBlurPresentationFactory(configuration: .fearlessBlur)
                await withCheckedContinuation { continuation in host.present(sheet, animated: false) { continuation.resume() } }
                window.layoutIfNeeded()
                let labels = recoveryDescendants(sheet.view).compactMap { $0 as? UILabel }
                for text in [model.title, try XCTUnwrap(model.message)] {
                    let label = try XCTUnwrap(labels.first { $0.text == text })
                    XCTAssertEqual(label.numberOfLines, 0)
                    XCTAssertGreaterThan(label.bounds.width, 0)
                    let required = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                    XCTAssertGreaterThanOrEqual(label.bounds.height + 1, required.height, "\(language) \(category): \(text)")
                    XCTAssertLessThanOrEqual(label.convert(label.bounds, to: sheet.view).maxX, sheet.view.bounds.width + 1)
                }
                captureRecovery(window, "cluster-unbound-\(language)-\(category.rawValue)-top")
                let controls = recoveryDescendants(sheet.view).compactMap { $0 as? TriangularedButton }
                let expectedTitle = category == .large ? model.actions[0].title : try XCTUnwrap(model.closeAction)
                let control = try XCTUnwrap(controls.first { $0.imageWithTitleView?.title == expectedTitle })
                var ancestor = control.superview
                while let view = ancestor {
                    if let scroll = view as? UIScrollView {
                        scroll.scrollRectToVisible(control.convert(control.bounds, to: scroll), animated: false)
                        break
                    }
                    ancestor = view.superview
                }
                window.layoutIfNeeded()
                let frame = control.convert(control.bounds, to: window)
                XCTAssertGreaterThanOrEqual(frame.width, 44)
                XCTAssertGreaterThanOrEqual(frame.height, 44)
                XCTAssertGreaterThanOrEqual(frame.minX, 0)
                XCTAssertLessThanOrEqual(frame.maxX, window.bounds.width + 1)
                XCTAssertGreaterThanOrEqual(frame.minY, window.safeAreaInsets.top)
                XCTAssertLessThanOrEqual(frame.maxY, window.bounds.height - window.safeAreaInsets.bottom + 1)
                let hit = window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil)
                XCTAssertTrue(hit === control || hit?.isDescendant(of: control) == true)
                captureRecovery(window, "cluster-unbound-\(language)-\(category.rawValue)-control")
                control.sendActions(for: .touchUpInside)
                for _ in 0..<100 {
                    if sheet.presentingViewController == nil { break }
                    try await Task.sleep(nanoseconds: 20_000_000)
                }
                XCTAssertNil(sheet.presentingViewController)
                XCTAssertTrue(context.interactor.retriedHashes.isEmpty)
                XCTAssertEqual(context.interactor.refreshFeeCount, 1)
                if category == .large { XCTAssertEqual(UIPasteboard.general.string, Self.solanaSignature) }
            }
        }
    }

    @MainActor
    func testSolanaUnreadableRecoveryActualSheetAllLocalesNormalAndAX5Close() async throws {
        let previousLanguage = LocalizationManager.shared.selectedLocalization
        defer { LocalizationManager.shared.selectedLocalization = previousLanguage }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let languages = ["en", "ru", "ja", "zh-Hans", "id", "vi", "tr", "pt-PT"]
        XCTAssertEqual(Set(Bundle.main.localizations.filter { $0 != "Base" }), Set(languages))
        for language in languages {
            LocalizationManager.shared.selectedLocalization = language
            for category in [UIContentSizeCategory.large, .accessibilityExtraExtraExtraLarge] {
                let context = makeSolanaConfirmPresenter()
                context.presenter.didTransfer(result: .failure(TransferServiceError.solanaRecoveryRecordUnreadable))
                let model = try XCTUnwrap(context.wireframe.presentedSheets.first)
                XCTAssertTrue(model.scrollableContent)
                let bundle = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)))
                let title = bundle.localizedString(forKey: "solana.transfer.recovery_unavailable.title", value: nil, table: nil)
                let message = bundle.localizedString(forKey: "solana.transfer.recovery_unreadable.message", value: nil, table: nil)
                XCTAssertFalse(title.hasPrefix("solana.transfer."))
                XCTAssertEqual(model.title, title)
                XCTAssertTrue(model.actions.isEmpty)
                XCTAssertEqual(model.closeAction, bundle.localizedString(forKey: "common.close", value: nil, table: nil))
                XCTAssertEqual(model.message, message)
                let clipboardBefore = UIPasteboard.general.string
                let window = UIWindow(windowScene: scene)
                window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
                window.overrideUserInterfaceStyle = .dark
                if #available(iOS 17.0, *) { window.traitOverrides.preferredContentSizeCategory = category }
                let host = UIViewController()
                window.rootViewController = host
                window.makeKeyAndVisible()
                defer { window.isHidden = true; window.rootViewController = nil }
                let sheet = SheetAletViewController(viewModel: model)
                sheet.modalPresentationStyle = .custom
                sheet.modalTransitioningFactory = ModalSheetBlurPresentationFactory(configuration: .fearlessBlur)
                await withCheckedContinuation { continuation in host.present(sheet, animated: false) { continuation.resume() } }
                window.layoutIfNeeded()
                let labels = recoveryDescendants(sheet.view).compactMap { $0 as? UILabel }
                for text in [model.title, try XCTUnwrap(model.message)] {
                    let label = try XCTUnwrap(labels.first { $0.text == text })
                    XCTAssertEqual(label.numberOfLines, 0)
                    XCTAssertGreaterThan(label.bounds.width, 0)
                    let required = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                    XCTAssertGreaterThanOrEqual(label.bounds.height + 1, required.height, "\(language) \(category): \(text)")
                    XCTAssertLessThanOrEqual(label.convert(label.bounds, to: sheet.view).maxX, sheet.view.bounds.width + 1)
                }
                captureRecovery(window, "record-unreadable-\(language)-\(category.rawValue)-top")
                let controls = recoveryDescendants(sheet.view).compactMap { $0 as? TriangularedButton }
                let expectedTitle = try XCTUnwrap(model.closeAction)
                let control = try XCTUnwrap(controls.first { $0.imageWithTitleView?.title == expectedTitle })
                var ancestor = control.superview
                while let view = ancestor {
                    if let scroll = view as? UIScrollView {
                        scroll.scrollRectToVisible(control.convert(control.bounds, to: scroll), animated: false)
                        break
                    }
                    ancestor = view.superview
                }
                window.layoutIfNeeded()
                let frame = control.convert(control.bounds, to: window)
                XCTAssertGreaterThanOrEqual(frame.width, 44)
                XCTAssertGreaterThanOrEqual(frame.height, 44)
                XCTAssertGreaterThanOrEqual(frame.minX, 0)
                XCTAssertLessThanOrEqual(frame.maxX, window.bounds.width + 1)
                XCTAssertGreaterThanOrEqual(frame.minY, window.safeAreaInsets.top)
                XCTAssertLessThanOrEqual(frame.maxY, window.bounds.height - window.safeAreaInsets.bottom + 1)
                let hit = window.hitTest(CGPoint(x: frame.midX, y: frame.midY), with: nil)
                XCTAssertTrue(hit === control || hit?.isDescendant(of: control) == true)
                captureRecovery(window, "record-unreadable-\(language)-\(category.rawValue)-control")
                control.sendActions(for: .touchUpInside)
                for _ in 0..<100 {
                    if sheet.presentingViewController == nil { break }
                    try await Task.sleep(nanoseconds: 20_000_000)
                }
                XCTAssertNil(sheet.presentingViewController)
                XCTAssertTrue(context.interactor.retriedHashes.isEmpty)
                XCTAssertEqual(context.interactor.refreshFeeCount, 1)
                XCTAssertEqual(UIPasteboard.general.string, clipboardBefore)
            }
        }
    }

    @MainActor
    private func recoveryDescendants(_ view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap { recoveryDescendants($0) }
    }

    @MainActor
    private func captureRecovery(_ window: UIWindow, _ name: String) {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSolanaUnknownOutcomeSheet_whenClosed_thenNothingIsRetried() throws {
        let context = makeSolanaConfirmPresenter()

        context.presenter.didTransfer(result: .failure(TransferServiceError.solanaBroadcastOutcomeUnknown(signature: Self.solanaSignature)))
        try XCTUnwrap(context.wireframe.presentedSheets.first).dismissCompletion?()

        XCTAssertTrue(context.interactor.retriedHashes.isEmpty)
    }

    func testSolanaEarlierTransferSheetsSayWhatHappenedAndRequote() throws {
        let cases: [(TransferServiceError, String)] = [
            (.solanaPriorTransferUnresolved(signature: Self.solanaSignature), "An earlier transfer is still in progress"),
            (.solanaPriorTransferConfirmed(signature: Self.solanaSignature), "Your earlier transfer was sent"),
            (.solanaPriorTransferNotSent(signature: Self.solanaSignature), "Your earlier transfer didn't go through"),
            (.solanaPriorTransferUnverified(signature: Self.solanaSignature), "Your earlier transfer could not be verified"),
            (.solanaTransferUnverified(signature: Self.solanaSignature), "This transfer could not be verified"),
            (.solanaTransferFailed(signature: Self.solanaSignature), "The transfer failed")
        ]
        for (error, title) in cases {
            let context = makeSolanaConfirmPresenter()

            context.presenter.didTransfer(result: .failure(error))

            let sheet = try XCTUnwrap(context.wireframe.presentedSheets.first, "\(error)")
            XCTAssertEqual(sheet.title, title)
            XCTAssertTrue(sheet.message?.contains(Self.solanaSignature) == true, "\(error)")
            XCTAssertEqual(sheet.actions.map(\.title), ["Copy transaction ID"])
            sheet.dismissCompletion?()
            XCTAssertEqual(context.interactor.refreshFeeCount, 1, "\(error)")
            XCTAssertTrue(context.interactor.retriedHashes.isEmpty, "\(error)")
            XCTAssertEqual(context.wireframe.extrinsicFailedCount, 0)
        }
    }

    /// An expiry too few nodes could prove never says nothing left the wallet: the sheet asks
    /// the user to check the balance and the transaction before sending again.
    func testSolanaUnverifiedSheetsNeverSayNothingLeftTheWallet() throws {
        for error in [
            TransferServiceError.solanaTransferUnverified(signature: Self.solanaSignature),
            .solanaPriorTransferUnverified(signature: Self.solanaSignature)
        ] {
            let context = makeSolanaConfirmPresenter()

            context.presenter.didTransfer(result: .failure(error))

            let sheet = try XCTUnwrap(context.wireframe.presentedSheets.first, "\(error)")
            let message = sheet.message ?? ""
            XCTAssertTrue(message.contains("Check your balance") && message.contains("Solscan"), message)
            XCTAssertFalse(message.contains("nothing left your wallet"), message)
            XCTAssertFalse(sheet.actions.map(\.title).contains("Retry sending"), "\(error)")
        }
    }

    func testSolanaTransferNotSentSaysSoForEveryReason() throws {
        for reason in [SolanaTransferNotSentReason.noConnection, .rejectedByNetwork, .expired(signature: Self.solanaSignature)] {
            let context = makeSolanaConfirmPresenter()

            context.presenter.didTransfer(result: .failure(TransferServiceError.solanaTransferNotSent(reason)))

            let sheet = try XCTUnwrap(context.wireframe.presentedSheets.first)
            XCTAssertEqual(sheet.title, "This transfer wasn't sent")
            XCTAssertTrue(sheet.message?.contains("nothing left your wallet") == true, "\(reason)")
            sheet.dismissCompletion?()
            XCTAssertEqual(context.interactor.refreshFeeCount, 1, "\(reason)")
        }
    }

    func testSolanaRecoverySheetsRefuseMalformedSignatures() {
        for signature in ["", "abc", "0" + String(Self.solanaSignature.dropFirst()), "\u{202E}" + Self.solanaSignature] {
            let context = makeSolanaConfirmPresenter()

            context.presenter.didTransfer(result: .failure(TransferServiceError.solanaBroadcastOutcomeUnknown(signature: signature)))

            XCTAssertTrue(context.wireframe.presentedSheets.isEmpty, signature)
        }
    }

    /// A remote balance read that failed (here: no node returned the token accounts) leaves no
    /// amount: neither one read earlier nor zero is offered as available or as Max.
    @MainActor
    func testSendScreen_whenTheBalanceCannotBeRead_thenNoAmountIsShown() async throws {
        let context = makePresenter(chainAsset: ChainAsset(chain: Self.solanaChain, asset: Self.solAsset))
        func drain() async {
            let drained = expectation(description: "main queue drained")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { drained.fulfill() }
            await fulfillment(of: [drained], timeout: 2)
        }
        context.presenter.didReceiveAssetAccountInfo(assetAccountInfo: nil)
        context.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: BigUInt(5_000_000_000))), for: context.chainAsset)
        await drain()
        XCTAssertEqual(context.view.assetBalances.last??.balance?.hasPrefix("5"), true)

        context.presenter.didReceiveAccountInfo(result: .failure(SolanaBalanceSyncError.tokenBalancesUnavailable), for: context.chainAsset)
        context.presenter.selectAmountPercentage(1, validate: false)
        await drain()
        XCTAssertNotNil(context.view.assetBalances.last ?? nil)
        XCTAssertNil(context.view.assetBalances.last??.balance, "No amount, not the one read earlier and not zero")
        XCTAssertEqual(context.view.amountInputs.last?.decimalAmount ?? 0, 0, "Max offers nothing")

        context.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: BigUInt(3_000_000_000))), for: context.chainAsset)
        await drain()
        XCTAssertEqual(context.view.assetBalances.last??.balance?.hasPrefix("3"), true)
    }

    /// The confirm screen's deposit row is fed by the fee quote: a quote that opens the
    /// recipient's token account shows the deposit, a later one that does not hides it.
    @MainActor
    func testSolanaConfirm_depositFromTheFeeQuoteReachesItsOwnRow() async throws {
        let context = makeConfirmPresenter(
            chainAsset: ChainAsset(chain: Self.solanaChain, asset: Self.solAsset),
            receiver: "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk"
        )
        var models: [WalletSendConfirmViewModel] = []
        var expected = expectation(description: "deposit row")
        expected.assertForOverFulfill = false
        context.view.onState = { state in
            guard case let .loaded(model) = state else { return }
            models.append(model)
            if !model.feeAmountString.isEmpty { expected.fulfill() }
        }
        context.presenter.didReceiveAccountCreationDeposit(BigUInt(2_039_280))
        context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(2_044_280))))
        await fulfillment(of: [expected], timeout: 2)
        XCTAssertTrue(models.last?.accountCreationAmountString.contains("0.00203928") == true, "\(String(describing: models.last))")
        XCTAssertTrue(models.last?.feeAmountString.contains("0.00204428") == true)

        expected = expectation(description: "no deposit row")
        expected.assertForOverFulfill = false
        models.removeAll()
        context.presenter.didReceiveAccountCreationDeposit(.zero)
        context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: BigUInt(5_000))))
        await fulfillment(of: [expected], timeout: 2)
        XCTAssertEqual(models.last?.accountCreationAmountString, "")
    }

    /// The interactor hands the presenter the deposit before the fee that includes it, on the
    /// main queue, so the row and the fee always describe the same quote.
    @MainActor
    func testSolanaConfirmInteractor_passesTheDepositBeforeTheFee() async throws {
        let chainAsset = ChainAsset(chain: Self.solanaChain, asset: Self.solAsset)
        let wallet = AccountGenerator.generateMetaAccount()
        let transfer = Transfer(chainAsset: chainAsset, amount: 1_000_000,
            receiver: "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk", tip: nil, appId: nil)
        let interactor = WalletSendConfirmInteractor(selectedMetaAccount: wallet, chainAsset: chainAsset,
            call: .transfer(transfer), accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared, selectedMetaAccount: wallet),
            dependencyContainer: Self.productionContainer(), wallet: wallet,
            accountInfoRemoteService: AccountInfoRemoteServiceStub())
        let output = ConfirmOutputRecorder()
        interactor.presenter = output
        let delivered = expectation(description: "fee delivered")
        output.onFee = { delivered.fulfill() }

        interactor.didReceiveSolanaFee(fee: BigUInt(2_044_280), accountCreationDeposit: BigUInt(2_039_280))
        await fulfillment(of: [delivered], timeout: 2)

        XCTAssertEqual(output.events, ["deposit:2039280", "fee:2044280"])
        XCTAssertTrue(output.mainThreadOnly)
    }

    func testSolanaRefusalAtConfirmExplainsItAndRequotes() {
        let context = makeSolanaConfirmPresenter()

        context.presenter.didTransfer(result: .failure(SolanaTransferRefusal.recipientIsTokenAccount))

        XCTAssertEqual(context.view.presentedSheetTitles, ["This is a token account, not a wallet"])
        XCTAssertEqual(context.wireframe.extrinsicFailedCount, 0)
        XCTAssertEqual(context.interactor.refreshFeeCount, 1)
    }

    func testSendScreen_whenTheFeeQuoteFindsATokenAccount_thenExplainsOncePerAddress() {
        let context = makePresenter(chainAsset: ChainAsset(chain: Self.solanaChain, asset: Self.solAsset))

        context.presenter.didReceiveFee(result: .failure(SolanaTransferRefusal.recipientIsTokenAccount))
        context.presenter.didReceiveFee(result: .failure(SolanaTransferRefusal.recipientIsTokenAccount))
        context.presenter.didReceiveFee(result: .failure(SolanaTransferRefusal.recipientIsProgram))
        context.presenter.didReceiveFee(result: .failure(TransferServiceError.cannotEstimateFee(reason: "offline")))

        XCTAssertEqual(
            context.view.presentedSheetTitles,
            ["This is a token account, not a wallet", "This is a program, not a wallet"]
        )
    }

    private func makeSolanaConfirmPresenter() -> ConfirmContext {
        makeConfirmPresenter(
            chainAsset: ChainAsset(chain: Self.solanaChain, asset: Self.solAsset),
            receiver: "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk"
        )
    }

    private static let solanaSignature =
        "5NfHnqDyzT9qyfxZDq2sSskAMGuFZ3VRqW4EQxghKqrKYdKq6cZNW1J34w7qE6nGx1eDQe5s2eKxB2ZtE1xU9qgN"

    // MARK: - Actual Solana presenter ownership baseline

    func testSolanaOwnershipBackRejectsLateSuccess() {
        let context = makeSolanaConfirmPresenter()
        context.presenter.didTapBackButton()
        XCTAssertEqual(context.wireframe.closeCount, 1)
        context.presenter.didTransfer(result: .success(Self.solanaSignature))
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty, "A departed review cannot navigate to success")
    }

    func testSolanaOwnershipBackRejectsLateUnknownOutcome() {
        let context = makeSolanaConfirmPresenter()
        context.presenter.didTapBackButton()
        context.presenter.didTransfer(result: .failure(TransferServiceError.solanaBroadcastOutcomeUnknown(signature: Self.solanaSignature)))
        XCTAssertTrue(context.wireframe.presentedSheets.isEmpty, "Late output must remain durable without taking over a departed screen")
        XCTAssertTrue(context.interactor.retriedHashes.isEmpty)
    }

    func testSolanaOwnershipRetainedRetryCannotActAfterBack() throws {
        let context = makeSolanaConfirmPresenter()
        context.presenter.didTransfer(result: .failure(TransferServiceError.solanaBroadcastOutcomeUnknown(signature: Self.solanaSignature)))
        let sheet = try XCTUnwrap(context.wireframe.presentedSheets.last)
        context.presenter.didTapBackButton()
        sheet.actions[0].handler?()
        sheet.dismissCompletion?()
        XCTAssertTrue(context.interactor.retriedHashes.isEmpty, "Old sheet callbacks cannot authorize another output")
    }

    func testSolanaOwnershipRecoveryDismissalIsConsumedOnce() throws {
        let context = makeSolanaConfirmPresenter()
        context.presenter.didTransfer(result: .failure(TransferServiceError.solanaBroadcastOutcomeUnknown(signature: Self.solanaSignature)))
        let sheet = try XCTUnwrap(context.wireframe.presentedSheets.last)
        sheet.actions[0].handler?()
        sheet.dismissCompletion?()
        sheet.dismissCompletion?()
        XCTAssertEqual(context.interactor.retriedHashes, [Self.solanaSignature])
    }

    func testSolanaOwnershipSupersededRecoveryCannotRetry() throws {
        let context = makeSolanaConfirmPresenter()
        context.presenter.didTransfer(result: .failure(TransferServiceError.solanaBroadcastOutcomeUnknown(signature: Self.solanaSignature)))
        let oldSheet = try XCTUnwrap(context.wireframe.presentedSheets.last)
        context.presenter.didTransfer(result: .failure(TransferServiceError.solanaRecoveryRecordUnreadable))
        XCTAssertEqual(context.wireframe.presentedSheets.count, 2)
        oldSheet.actions[0].handler?()
        oldSheet.dismissCompletion?()
        XCTAssertTrue(context.interactor.retriedHashes.isEmpty, "An unavailable current recovery supersedes an old retry action")
    }

    func testSolanaOwnershipSuccessfulReceiptIsConsumedOnce() {
        let context = makeSolanaConfirmPresenter()
        context.presenter.didTransfer(result: .success(Self.solanaSignature))
        context.presenter.didTransfer(result: .success(Self.solanaSignature))
        XCTAssertEqual(context.wireframe.completedHashes, [Self.solanaSignature])
    }

    func testSolanaOwnershipCurrentSuccessfulReceiptRemainsAvailable() {
        let context = makeSolanaConfirmPresenter()
        context.presenter.didTransfer(result: .success(Self.solanaSignature))
        XCTAssertEqual(context.wireframe.completedHashes, [Self.solanaSignature])
        XCTAssertTrue(context.interactor.retriedHashes.isEmpty)
        XCTAssertTrue(context.wireframe.presentedSheets.isEmpty)
    }

    func testSolanaOwnershipCurrentRecoveryRetryAndCloseRemainDistinct() throws {
        let context = makeSolanaConfirmPresenter()
        context.presenter.didTransfer(result: .failure(TransferServiceError.solanaBroadcastOutcomeUnknown(signature: Self.solanaSignature)))
        let sheet = try XCTUnwrap(context.wireframe.presentedSheets.last)
        sheet.actions[0].handler?()
        sheet.dismissCompletion?()
        XCTAssertEqual(context.interactor.retriedHashes, [Self.solanaSignature])
        let closed = makeSolanaConfirmPresenter()
        closed.presenter.didTransfer(result: .failure(TransferServiceError.solanaBroadcastOutcomeUnknown(signature: Self.solanaSignature)))
        try XCTUnwrap(closed.wireframe.presentedSheets.last).dismissCompletion?()
        XCTAssertTrue(closed.interactor.retriedHashes.isEmpty)
    }

    // MARK: - Builders

    private struct PresenterContext {
        let presenter: SendPresenter
        let interactor: SendInteractorStub
        let router: SendRouterSpy
        let view: SendViewStub
        let chainAsset: ChainAsset
        var validating: SendDataValidatingFactory? = nil
    }

    private func makePresenter(chainAsset: ChainAsset) -> PresenterContext {
        let interactor = SendInteractorStub(container: Self.productionContainer())
        let router = SendRouterSpy()
        let view = SendViewStub()
        let presenter = SendPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            viewModelFactory: SendViewModelFactoryStub(),
            dataValidatingFactory: SendDataValidatingFactory(presentable: router),
            wallet: AccountGenerator.generateMetaAccount(),
            initialData: .chainAsset(chainAsset)
        )
        presenter.didLoad(view: view)
        return PresenterContext(
            presenter: presenter,
            interactor: interactor,
            router: router,
            view: view,
            chainAsset: chainAsset
        )
    }

    private struct ConfirmContext {
        let presenter: WalletSendConfirmPresenter
        let interactor: WalletSendConfirmInteractorStub
        let wireframe: WalletSendConfirmWireframeSpy
        let view: WalletSendConfirmViewStub
        let chainAsset: ChainAsset
    }

    private func makeConfirmPresenter(
        chainAsset: ChainAsset = ChainAsset(chain: SendDependencyErrorSurfacingTests.bitcoinChain, asset: SendDependencyErrorSurfacingTests.btcAsset),
        receiver: String = "bc1qslk39wvggqa0vl8nd6jckaz54dw3vk45c5w60m"
    ) -> ConfirmContext {
        let wireframe = WalletSendConfirmWireframeSpy()
        let view = WalletSendConfirmViewStub()
        let interactor = WalletSendConfirmInteractorStub(container: Self.productionContainer())
        let presenter = WalletSendConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            accountViewModelFactory: AccountViewModelFactory(iconGenerator: UniversalIconGenerator()),
            dataValidatingFactory: SendDataValidatingFactory(presentable: wireframe),
            walletSendConfirmViewModelFactory: WalletSendConfirmViewModelFactory(
                amountFormatterFactory: AssetBalanceFormatterFactory(),
                assetInfo: chainAsset.asset.displayInfo(with: chainAsset.chain.icon)
            ),
            logger: nil,
            chainAsset: chainAsset,
            wallet: AccountGenerator.generateMetaAccount(),
            call: .transfer(
                Transfer(
                    chainAsset: chainAsset,
                    amount: BigUInt(50000),
                    receiver: receiver,
                    tip: nil,
                    appId: nil
                )
            ),
            scamInfo: nil,
            feeViewModel: nil,
            localizationManager: LocalizationManager.shared
        )
        presenter.view = view
        return ConfirmContext(
            presenter: presenter,
            interactor: interactor,
            wireframe: wireframe,
            view: view,
            chainAsset: chainAsset
        )
    }

    private static func productionContainer() -> SendDepencyContainer {
        SendDepencyContainer(
            wallet: AccountGenerator.generateMetaAccount(),
            operationManager: fearless.OperationManagerFacade.sharedManager
        )
    }

    private static func makeInteractor(container: SendDepencyContainer, prepareDependencies: ((ChainAsset) async throws -> SendDependencies)? = nil) -> SendInteractor {
        let wallet = AccountGenerator.generateMetaAccount()
        let chainRepository = ChainRepositoryFactory().createRepository(
            for: NSPredicate.enabledCHain(),
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let runtimeMetadataRepository: AsyncCoreDataRepositoryDefault<fearless.RuntimeMetadataItem, SSFAssetManagmentStorage.CDRuntimeMetadataItem> =
            SubstrateDataStorageFacade.shared.createAsyncRepository()

        return SendInteractor(
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: wallet
            ),
            operationManager: fearless.OperationManagerFacade.sharedManager,
            scamInfoFetching: ScamInfoFetchingStub(),
            chainAssetFetching: ChainAssetsFetching(
                chainRepository: AnyDataProviderRepository(chainRepository),
                operationQueue: OperationQueue()
            ),
            dependencyContainer: container,
            addressChainDefiner: AddressChainDefiner(
                operationManager: fearless.OperationManagerFacade.sharedManager,
                chainModelRepository: AnyDataProviderRepository(chainRepository),
                wallet: wallet
            ),
            runtimeItemRepository: AsyncAnyRepository(runtimeMetadataRepository),
            accountInfoRemoteService: AccountInfoRemoteServiceStub(),
            prepareDependencies: prepareDependencies
        )
    }

    private static let bitcoinVeto = FeatureToggleConfig(
        pendulumCaseEnabled: false,
        nftEnabled: true,
        bitcoinSendEnabled: false,
        explicitKillSwitches: [.bitcoinSend: false]
    )

    private static let btcAsset = AssetModel(
        id: "BTC",
        name: "Bitcoin",
        symbol: "BTC",
        precision: 8,
        isUtility: true,
        isNative: true
    )
    private static let solAsset = AssetModel(
        id: "SOL",
        name: "Solana",
        symbol: "SOL",
        precision: 9,
        isUtility: true,
        isNative: true
    )
    private static let tonAsset = AssetModel(
        id: "TON",
        name: "Toncoin",
        symbol: "TON",
        precision: 9,
        isUtility: true,
        isNative: true
    )
    private static let bitcoinChain = chain(chainId: UniversalWalletRegistry.bitcoinMainnet.chainId, name: "Bitcoin", asset: btcAsset)
    private static let solanaChain = chain(chainId: UniversalWalletRegistry.solanaMainnet.chainId, name: "Solana", asset: solAsset)
    private static let tonChain = chain(chainId: TonChainSelection.mainnetChainId, name: "TON", asset: tonAsset)

    private static func chain(chainId: String, name: String, asset: AssetModel) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: name,
            assets: [asset],
            xcm: nil,
            nodes: [],
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
    }
}

// MARK: - Doubles

private final class SendInteractorOutputSpy: SendInteractorOutput {
    var errorExpectation: XCTestExpectation?
    private(set) var receivedErrors: [(Error, ChainAsset)] = []
    private(set) var receivedOnMainThread: [Bool] = []
    private(set) var dependenciesReceivedCount = 0

    func didReceiveDependenciesError(_ error: Error, for chainAsset: ChainAsset) {
        receivedErrors.append((error, chainAsset))
        receivedOnMainThread.append(Thread.isMainThread)
        errorExpectation?.fulfill()
    }

    func didReceiveDependencies(for _: ChainAsset) {
        dependenciesReceivedCount += 1
    }

    func didReceiveAccountInfo(result _: Result<AccountInfo?, Error>, for _: ChainAsset) {}
    func didReceiveMinimumBalance(result _: Result<BigUInt, Error>) {}
    func didReceiveFee(result _: Result<RuntimeDispatchInfo, Error>) {}
    func didReceiveTip(result _: Result<BigUInt, Error>) {}
    func didReceive(scamInfo _: ScamInfo?) {}
    func didReceive(possibleChains _: [ChainModel]?) {}
    func didReceive(eqTotalBalance _: Decimal) {}
    func didReceiveAssetAccountInfo(assetAccountInfo _: AssetAccountInfo?) {}
    func didReceiveAssetAccountInfoError(error _: Error) {}
}

private final class SendInteractorStub: SendInteractorInput {
    let dependencyContainer: SendDepencyContainer
    var convertAction: (() async throws -> SwapValues?)?
    private(set) var updatedChainAssets: [ChainAsset] = []

    init(container: SendDepencyContainer) {
        dependencyContainer = container
    }

    func setup(with _: SendInteractorOutput) {}

    func updateSubscriptions(for chainAsset: ChainAsset) {
        updatedChainAssets.append(chainAsset)
    }

    var deferNetworks = false
    var pendingNetworks: (([ChainModel]?) -> Void)?
    func defineAvailableChains(
        for _: ChainAsset,
        wallet _: MetaAccountModel,
        completionBlock: @escaping ([ChainModel]?) -> Void
    ) {
        if deferNetworks { pendingNetworks = completionBlock }
        else { completionBlock(nil) }
    }

    private(set) var estimatedAmounts: [BigUInt] = []
    func estimateFee(for amount: BigUInt, tip _: BigUInt?, for _: String?, chainAsset _: ChainAsset) { estimatedAmounts.append(amount) }

    var validationOverride: AddressValidationResult?
    var validationForInput: ((String?) -> AddressValidationResult)?
    func validate(address: String?, for _: ChainModel) -> AddressValidationResult {
        validationForInput?(address) ?? validationOverride ?? .invalid(address)
    }

    func fetchScamInfo(for _: String, chain _: ChainModel) {}

    func getFeePaymentChainAsset(for chainAsset: ChainAsset?) -> ChainAsset? {
        chainAsset
    }

    func getPossibleChains(for _: String) async -> [ChainModel]? {
        nil
    }

    func calculateEquilibriumBalance(chainAsset _: ChainAsset, amount _: Decimal) {}
    func didReceive(xorlessTransfer _: XorlessTransfer) {}

    func convert(chainAsset _: ChainAsset, toChainAsset _: ChainAsset, amount _: BigUInt) async throws -> SwapValues? {
        try await convertAction?()
    }

    func provideConstants(for _: ChainAsset) {}
}

private final class SendRouterSpy: SendRouterInput {
    var sheetForwarder: ((SheetAlertPresentableViewModel, ControllerBackedProtocol?) -> Void)?
    var formWarningForwarder: ((SheetAlertPresentableViewModel, ControllerBackedProtocol?) -> Void)?

    func presentFormWarning(viewModel: SheetAlertPresentableViewModel, from view: ControllerBackedProtocol?) {
        presentedSheets.append(viewModel)
        formWarningForwarder?(viewModel, view)
    }

    private(set) var confirmations: [(wallet: MetaAccountModel, asset: ChainAsset, call: SendConfirmTransferCall, selection: SelectedWalletAuthority.Lease?)] = []
    private(set) var networkPickers = 0
    private(set) var presentedSheets: [SheetAlertPresentableViewModel] = []
    private(set) var receiveChainAssets: [ChainAsset] = []
    private(set) var dismissCount = 0

    func present(viewModel: SheetAlertPresentableViewModel, from view: ControllerBackedProtocol?) {
        presentedSheets.append(viewModel)
        sheetForwarder?(viewModel, view)
    }

    func present(message: String?, title: String, closeAction: String?,
                 from _: ControllerBackedProtocol?, actions: [SheetAlertPresentableAction]) {
        presentedSheets.append(SheetAlertPresentableViewModel(
            title: title, message: message, actions: actions, isInfo: false, closeAction: closeAction))
    }

    func presentReceive(
        leavingSendFlowFrom _: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet _: MetaAccountModel
    ) {
        receiveChainAssets.append(chainAsset)
    }

    func dismiss(view _: ControllerBackedProtocol?) {
        dismissCount += 1
    }

    func presentConfirm(
        from _: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        call: SendConfirmTransferCall,
        scamInfo _: ScamInfo?,
        feeViewModel _: BalanceViewModelProtocol?,
        selection: SelectedWalletAuthority.Lease?
    ) { confirmations.append((wallet, chainAsset, call, selection)) }

    func presentScan(from _: ControllerBackedProtocol?, moduleOutput _: ScanQRModuleOutput) {}

    func presentHistory(
        from _: ControllerBackedProtocol?,
        wallet _: MetaAccountModel,
        chainAsset _: ChainAsset,
        moduleOutput _: ContactsModuleOutput
    ) {}

    func showSelectNetwork(
        from _: ControllerBackedProtocol?,
        wallet _: MetaAccountModel,
        selectedChainId _: ChainModel.Id?,
        chainModels _: [ChainModel]?,
        delegate _: SelectNetworkDelegate?
    ) { networkPickers += 1 }

    func showSelectAsset(
        from _: ControllerBackedProtocol?,
        wallet _: MetaAccountModel,
        selectedAssetId _: AssetModel.Id?,
        chainAssets _: [ChainAsset]?,
        output _: SelectAssetModuleOutput
    ) {}

    func showManageAsset(from _: ControllerBackedProtocol?, wallet _: MetaAccountModel) {}
}

private struct SendViewModelFactoryStub: SendViewModelFactoryProtocol {
    func buildRecipientViewModel(address: String, isValid: Bool, canEditing: Bool) -> RecipientViewModel {
        RecipientViewModel(address: address, icon: nil, isValid: isValid, canEditing: canEditing)
    }

    func buildNetworkViewModel(chain: ChainModel, canEdit: Bool) -> SelectNetworkViewModel {
        SelectNetworkViewModel(chainName: chain.name, iconViewModel: nil, canEdit: canEdit)
    }

    func buildAccountScoreViewModel(address _: String?, chain _: ChainModel) -> AccountScoreViewModel? {
        nil
    }
}

private final class SendViewStub: UIViewController, SendViewInput {
    private(set) var feeModels: [BalanceViewModelProtocol?] = []
    private(set) var amountInputs: [IAmountInputViewModel] = []
    private(set) var sendAllStates: [Bool] = []
    /// Error messages reach the screen as a sheet presented on the view itself.
    private(set) var presentedSheetTitles: [String] = []

    override func present(_ controller: UIViewController, animated _: Bool, completion _: (() -> Void)? = nil) {
        let viewModel = Mirror(reflecting: controller).children.first { $0.label == "viewModel" }?.value
        if let viewModel = viewModel as? SheetAlertPresentableViewModel {
            presentedSheetTitles.append(viewModel.title)
        }
    }

    var loadableContentView: UIView {
        view
    }

    var shouldDisableInteractionWhenLoading: Bool {
        false
    }

    func didStartLoading() {}
    func didStopLoading() {}
    private(set) var assetBalances: [AssetBalanceViewModelProtocol?] = []
    func didReceive(assetBalanceViewModel: AssetBalanceViewModelProtocol?) { assetBalances.append(assetBalanceViewModel) }
    func didReceive(amountInputViewModel: IAmountInputViewModel?) { if let amountInputViewModel { amountInputs.append(amountInputViewModel) } }
    func didReceive(selectNetworkViewModel _: SelectNetworkViewModel) {}
    func didReceive(feeViewModel: BalanceViewModelProtocol?) { feeModels.append(feeViewModel) }
    func didReceive(tipViewModel _: TipViewModel?) {}
    func didReceive(scamInfo _: ScamInfo?) {}
    func didStartFeeCalculation() {}
    func didStopFeeCalculation() {}
    func didStopTipCalculation() {}
    func didReceive(viewModel _: RecipientViewModel) {}
    func didReceive(accountScoreViewModel _: AccountScoreViewModel?) {}
    func didBlockUserInteractive(isUserInteractiveAmount _: Bool) {}
    func setInputAccessoryView(visible _: Bool) {}
    func setHistoryButton(isVisible _: Bool) {}
    func switchEnableSendAllState(enabled: Bool) { sendAllStates.append(enabled) }
    func switchEnableSendAllVisibility(isVisible _: Bool) {}
}

private final class WalletSendConfirmInteractorStub: WalletSendConfirmInteractorInputProtocol {
    let dependencyContainer: SendDepencyContainer

    init(container: SendDepencyContainer) {
        dependencyContainer = container
    }

    func setup() {}
    private(set) var submittedCount = 0
    func submitExtrinsic() { submittedCount += 1 }

    func getFeePaymentChainAsset(for chainAsset: ChainAsset?) -> ChainAsset? {
        chainAsset
    }

    func fetchEquilibriumTotalBalance(chainAsset _: ChainAsset, amount _: Decimal) {}
    func provideConstants() {}

    func confirmFeePresentation(fee _: BigUInt, completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    func acknowledgeSubmittedTransfer(
        hash _: String,
        recoveredIdentity _: TonTransferIntentIdentity?,
        completion: @escaping (Bool) -> Void
    ) {
        completion(true)
    }

    private(set) var refreshFeeCount = 0
    private(set) var retriedHashes: [String] = []
    private(set) var replacementRequests: [String] = []
    var allowsReplacement = true

    func refreshFee() {
        refreshFeeCount += 1
    }

    func retryUnresolvedTransfer(hash: String) {
        retriedHashes.append(hash)
    }

    func allowReplacingUnresolvedTransfer(hash: String, completion: @escaping (Bool) -> Void) {
        replacementRequests.append(hash)
        completion(allowsReplacement)
    }
}

private final class WalletSendConfirmWireframeSpy: WalletSendConfirmWireframeProtocol {
    private(set) var presentedSheets: [SheetAlertPresentableViewModel] = []
    private(set) var receiveChainAssets: [ChainAsset] = []
    private(set) var finishCount = 0
    private(set) var extrinsicFailedCount = 0

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        presentedSheets.append(viewModel)
    }

    func presentReceive(
        leavingSendFlowFrom _: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet _: MetaAccountModel
    ) {
        receiveChainAssets.append(chainAsset)
    }

    func presentExtrinsicFailed(from _: ControllerBackedProtocol, locale _: Locale?) {
        extrinsicFailedCount += 1
    }

    private(set) var closeCount = 0
    private(set) var completedHashes: [String] = []

    func close(view _: ControllerBackedProtocol?) { closeCount += 1 }

    func finish(view _: ControllerBackedProtocol?) {
        finishCount += 1
    }

    func complete(on _: ControllerBackedProtocol?, title: String, chainAsset _: ChainAsset) { completedHashes.append(title) }

    func presentSuccessNotification(
        _: String,
        from _: ControllerBackedProtocol?,
        completion _: (() -> Void)?
    ) {}
}

private final class WalletSendConfirmViewStub: UIViewController, WalletSendConfirmViewProtocol {
    /// Error messages reach the screen as a sheet presented on the view itself.
    private(set) var presentedSheetTitles: [String] = []

    override func present(_ controller: UIViewController, animated _: Bool, completion _: (() -> Void)? = nil) {
        let viewModel = Mirror(reflecting: controller).children.first { $0.label == "viewModel" }?.value
        if let viewModel = viewModel as? SheetAlertPresentableViewModel {
            presentedSheetTitles.append(viewModel.title)
        }
    }

    var loadableContentView: UIView {
        view
    }

    var shouldDisableInteractionWhenLoading: Bool {
        false
    }

    var onStartLoading: (() -> Void)?
    var onStopLoading: (() -> Void)?
    func didStartLoading() { onStartLoading?() }
    func didStopLoading() { onStopLoading?() }
    var onState: ((WalletSendConfirmViewState) -> Void)?
    func didReceive(state: WalletSendConfirmViewState) { onState?(state) }
    func didReceive(isLoading _: Bool) {}
}

/// Records what the confirm interactor tells its presenter, and on which thread.
private final class ConfirmOutputRecorder: WalletSendConfirmInteractorOutputProtocol {
    private(set) var events: [String] = []
    private(set) var mainThreadOnly = true
    var onFee: (() -> Void)?

    private func record(_ event: String) {
        if !Thread.isMainThread { mainThreadOnly = false }
        events.append(event)
    }

    func didReceiveAccountInfo(result _: Result<AccountInfo?, Error>, for _: ChainAsset) {}
    func didReceiveMinimumBalance(result _: Result<BigUInt, Error>) {}
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        if case let .success(info) = result { record("fee:\(info.fee)") }
        onFee?()
    }

    func didReceive(eqTotalBalance _: Decimal) {}
    func didTransfer(result _: Result<String, Error>) {}
    func didReceiveAccountCreationDeposit(_ deposit: BigUInt) { record("deposit:\(deposit)") }
}

private struct ScamInfoFetchingStub: ScamInfoFetching {
    func fetch(address _: String, chain _: ChainModel) async throws -> ScamInfo? {
        nil
    }
}

private struct AccountInfoRemoteServiceStub: AccountInfoRemoteService {
    func fetchAccountInfos(for _: ChainModel, wallet _: MetaAccountModel) async throws -> [ChainAssetId: AccountInfo?] {
        [:]
    }

    func fetchAccountInfo(for _: ChainAsset, wallet _: MetaAccountModel) async throws -> AccountInfo? {
        nil
    }
}

// Actual presenter -> interactor -> Solana service/client/broadcaster/store. Public phrase;
// deterministic in-memory HTTP transport, no URLSession, network or user keychain access.
extension SendDependencyErrorSurfacingTests {
    @MainActor
    func testSolanaPipelineBackBeforeKeyReadStopsNewWork() async throws {
        let context = try makeSolanaPipeline(hold: .firstGenesis)
        context.interactor.submitExtrinsic()
        await fulfillment(of: [context.transport.entered], timeout: 5)
        let task = try XCTUnwrap(context.interactor.transferTask)
        XCTAssertEqual(context.keys.reads, 0)
        context.presenter.didTapBackButton()
        await context.transport.gate.open()
        await task.value
        XCTAssertEqual(context.keys.reads, 0, "Departure before key access must revoke the old request")
        XCTAssertTrue(context.transport.sent.isEmpty)
        XCTAssertEqual(context.store.readState(for: context.scope), .absent)
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty)
        XCTAssertTrue(context.wireframe.presentedSheets.isEmpty)
    }

    @MainActor
    func testSolanaPipelineBackBeforeOutputCannotSendRetainedBytes() async throws {
        let context = try makeSolanaPipeline(hold: .sendGenesis)
        context.interactor.submitExtrinsic()
        await fulfillment(of: [context.transport.entered], timeout: 5)
        let task = try XCTUnwrap(context.interactor.transferTask)
        let original = try XCTUnwrap(context.store.pending(for: context.scope))
        XCTAssertEqual(context.keys.reads, 1)
        XCTAssertEqual(context.transport.simulations, 1)
        XCTAssertTrue(context.transport.sent.isEmpty)
        context.presenter.didTapBackButton()
        await context.transport.gate.open()
        await task.value
        XCTAssertTrue(context.transport.sent.isEmpty, "Pre-output departure must not reach the local writer")
        XCTAssertEqual(context.store.pending(for: context.scope)?.transactionBase64, original.transactionBase64)
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty)
        XCTAssertTrue(context.wireframe.presentedSheets.isEmpty)
    }

    @MainActor
    func testSolanaPipelineBackAfterOutputRetainsAckWithoutNavigation() async throws {
        let context = try makeSolanaPipeline(hold: .output)
        context.interactor.submitExtrinsic()
        await fulfillment(of: [context.transport.entered], timeout: 5)
        let task = try XCTUnwrap(context.interactor.transferTask)
        let original = try XCTUnwrap(context.store.pending(for: context.scope))
        XCTAssertEqual(context.transport.sent, [original.transactionBase64])
        context.presenter.didTapBackButton()
        await context.transport.gate.open()
        await task.value
        XCTAssertEqual(context.store.pending(for: context.scope)?.transactionBase64, original.transactionBase64)
        XCTAssertEqual(context.transport.sent.count, 1)
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty, "Acknowledged output stays durable, without taking over the old screen")
        XCTAssertTrue(context.wireframe.presentedSheets.isEmpty)
    }

    @MainActor
    func testSolanaPipelineBackAfterLostOutputRetainsRecordWithoutAlert() async throws {
        let context = try makeSolanaPipeline(hold: .output)
        context.transport.loseResponse = true
        context.interactor.submitExtrinsic()
        await fulfillment(of: [context.transport.entered], timeout: 5)
        let task = try XCTUnwrap(context.interactor.transferTask)
        let original = try XCTUnwrap(context.store.pending(for: context.scope))
        context.presenter.didTapBackButton()
        await context.transport.gate.open()
        await task.value
        XCTAssertEqual(context.store.pending(for: context.scope), original)
        XCTAssertEqual(context.transport.sent.count, 1)
        XCTAssertTrue(context.wireframe.presentedSheets.isEmpty, "Unknown output remains recoverable without a stale alert")
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty)
    }

    @MainActor
    func testSolanaPipelineCurrentAckKeepsExactPendingAndReceipt() async throws {
        let context = try makeSolanaPipeline(hold: .none)
        context.interactor.submitExtrinsic()
        try await XCTUnwrap(context.interactor.transferTask).value
        let record = try XCTUnwrap(context.store.pending(for: context.scope))
        XCTAssertEqual(context.keys.reads, 1)
        XCTAssertEqual(context.transport.sent, [record.transactionBase64])
        XCTAssertTrue(record.reportedAsSent)
        XCTAssertEqual(context.wireframe.completedHashes, [record.signature])
        XCTAssertTrue(context.wireframe.presentedSheets.isEmpty)
    }

    @MainActor
    func testSolanaPipelineCurrentRecoveryReusesExactBytesWithoutKeys() async throws {
        let context = try makeSolanaPipeline(hold: .none)
        context.transport.loseResponse = true
        context.interactor.submitExtrinsic()
        try await XCTUnwrap(context.interactor.transferTask).value
        let record = try XCTUnwrap(context.store.pending(for: context.scope))
        let sheet = try XCTUnwrap(context.wireframe.presentedSheets.last)
        context.transport.loseResponse = false
        sheet.actions[0].handler?()
        sheet.dismissCompletion?()
        try await XCTUnwrap(context.interactor.transferTask).value
        XCTAssertEqual(context.transport.sent, [record.transactionBase64, record.transactionBase64])
        XCTAssertEqual(context.keys.reads, 1)
        XCTAssertEqual(context.wireframe.completedHashes, [record.signature])
        XCTAssertTrue(try XCTUnwrap(context.store.pending(for: context.scope)).reportedAsSent)
    }

    private struct SolanaPipelineContext {
        let presenter: WalletSendConfirmPresenter
        let interactor: WalletSendConfirmInteractor
        let wireframe: WalletSendConfirmWireframeSpy
        let view: WalletSendConfirmViewStub
        let store: SolanaPendingBroadcastStore
        let scope: SolanaPendingBroadcastScope
        let transport: SolanaPipelineTransport
        let keys: SolanaPipelineKeys
    }

    @MainActor
    private func makeSolanaPipeline(hold: SolanaPipelineTransport.Hold, selectedWallet: MetaAccountModel? = nil, selectionSettings: SelectedWalletSettings? = nil, retainedRead: SolanaPipelineReadHold? = nil, originatingSelection: SelectedWalletAuthority.Lease? = nil) throws -> SolanaPipelineContext {
        let chainAsset = ChainAsset(chain: Self.solanaChain, asset: Self.solAsset)
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: SolanaPipelineKeys.phrase)
        let chainAccount = ChainAccountModel(chainId: Self.solanaChain.chainId, accountId: account.publicKey,
            publicKey: account.publicKey, cryptoType: CryptoType.ed25519.rawValue, ethereumBased: false)
        let wallet = selectedWallet ?? AccountGenerator.generateMetaAccount(with: [chainAccount])
        let settings = selectionSettings ?? SelectedWalletSettings(
            storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue()
        )
        if selectionSettings == nil { settings.applySetupResult(.success(wallet)) }
        let transport = SolanaPipelineTransport(hold: hold, entered: XCTestExpectation(description: "local held boundary"))
        let keys = SolanaPipelineKeys()
        let store = SolanaPendingBroadcastStore(userDefaults: UserDefaults(suiteName: "send-owner-\(UUID().uuidString)")!, logger: nil)
        let client = try SolanaRpcClient(transport: transport)
        let service = try SolanaTransferService(wallet: wallet, chain: Self.solanaChain,
            rpcClient: client, mnemonicProvider: keys, pendingStore: retainedRead.map { HeldSolanaPipelineStore(store: store, hold: $0) as SolanaPendingBroadcastStoring } ?? store,
            confirmationPolicy: .init(timeout: 0, pollInterval: 0), providerRPCURL: nil)
        let transfer = Transfer(chainAsset: chainAsset, amount: 1_000_000,
            receiver: "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk", tip: nil, appId: nil)
        let container = SendDepencyContainer(wallet: wallet, operationManager: fearless.OperationManagerFacade.sharedManager)
        let interactor = WalletSendConfirmInteractor(selectedMetaAccount: wallet, chainAsset: chainAsset,
            call: .transfer(transfer), accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared, selectedMetaAccount: wallet),
            dependencyContainer: container, wallet: wallet, accountInfoRemoteService: AccountInfoRemoteServiceStub(),
            prepareTransferService: { _ in
                if hold == .preparation {
                    transport.entered.fulfill()
                    await transport.gate.wait()
                }
                return service
            }, selectedWalletSettings: settings, selection: originatingSelection)
        let wireframe = WalletSendConfirmWireframeSpy()
        let view = WalletSendConfirmViewStub()
        let presenter = WalletSendConfirmPresenter(interactor: interactor, wireframe: wireframe,
            accountViewModelFactory: AccountViewModelFactory(iconGenerator: UniversalIconGenerator()),
            dataValidatingFactory: SendDataValidatingFactory(presentable: wireframe),
            walletSendConfirmViewModelFactory: WalletSendConfirmViewModelFactory(amountFormatterFactory: AssetBalanceFormatterFactory(),
                assetInfo: chainAsset.asset.displayInfo(with: chainAsset.chain.icon)), logger: nil,
            chainAsset: chainAsset, wallet: wallet, call: .transfer(transfer), scamInfo: nil, feeViewModel: nil,
            localizationManager: LocalizationManager.shared)
        presenter.view = view
        interactor.presenter = presenter
        return SolanaPipelineContext(presenter: presenter, interactor: interactor, wireframe: wireframe, view: view,
            store: store, scope: SolanaPendingBroadcastScope(walletId: wallet.metaId, chainId: Self.solanaChain.chainId),
            transport: transport, keys: keys)
    }

    private final class SolanaPipelineKeys: UniversalWalletMnemonicProviding {
        static let phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        private(set) var reads = 0
        func mnemonic(for _: MetaAccountModel, chain _: ChainModel) throws -> String? {
            reads += 1
            return Self.phrase
        }
    }

    private actor SolanaPipelineGate {
        private var opened = false
        private var waiters: [CheckedContinuation<Void, Never>] = []
        func wait() async {
            guard !opened else { return }
            await withCheckedContinuation { waiters.append($0) }
        }
        func open() {
            opened = true
            waiters.forEach { $0.resume() }
            waiters.removeAll()
        }
    }

    private final class SolanaPipelineTransport: UniversalWalletHTTPTransport {
        enum Hold { case none, preparation, firstGenesis, sendGenesis, output }
        let hold: Hold
        let entered: XCTestExpectation
        let gate = SolanaPipelineGate()
        private var didHold = false
        private(set) var simulations = 0
        private(set) var sent: [String] = []
        var loseResponse = false
        init(hold: Hold, entered: XCTestExpectation) { self.hold = hold; self.entered = entered }
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

        func perform(_ request: URLRequest) async throws -> Data {
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
            let method = try XCTUnwrap(object["method"] as? String)
            let shouldHold = (hold == .firstGenesis && method == "getGenesisHash") ||
                (hold == .sendGenesis && method == "getGenesisHash" && simulations > 0) ||
                (hold == .output && method == "sendTransaction")
            if method == "sendTransaction" {
                sent.append(try XCTUnwrap((object["params"] as? [Any])?.first as? String))
            }
            if shouldHold && !didHold {
                didHold = true
                entered.fulfill()
                await gate.wait() // Intentionally ignores cancellation; caller owns the boundary.
            }
            let result: Any
            switch method {
            case "getGenesisHash": result = UniversalWalletRegistry.solanaMainnet.genesisHash
            case "getAccountInfo": result = ["context": ["slot": 1], "value": NSNull()] as [String: Any]
            case "getRecentPrioritizationFees": result = [] as [Int]
            case "getLatestBlockhash": result = ["context": ["slot": 1], "value": ["blockhash": "11111111111111111111111111111111", "lastValidBlockHeight": 9999]] as [String: Any]
            case "getFeeForMessage": result = ["context": ["slot": 1], "value": 5000] as [String: Any]
            case "getBalance": result = ["context": ["slot": 1], "value": 2_000_000_000] as [String: Any]
            case "getMinimumBalanceForRentExemption": result = 0
            case "getTokenAccountsByOwner": result = ["context": ["slot": 1], "value": []] as [String: Any]
            case "simulateTransaction":
                simulations += 1
                result = ["context": ["slot": 1], "value": ["err": NSNull(), "logs": [], "unitsConsumed": 42]] as [String: Any]
            case "sendTransaction":
                if loseResponse { throw URLError(.networkConnectionLost) }
                let wire = try XCTUnwrap(sent.last)
                let sender = try SolanaKeyDerivation.deriveAccount(mnemonic: SolanaPipelineKeys.phrase).address
                let regenerated = try SolanaTransactionSigner.signSerializedTransaction(mnemonic: SolanaPipelineKeys.phrase,
                    transactionBase64: wire, expectedSigner: sender).signatureBase58
                let original = try Self.firstSignature(wire)
                print("PUBLIC_FIXTURE_ACK original=\(original) regenerated=\(regenerated)")
                result = original
            case "getSignatureStatuses": result = ["context": ["slot": 2], "value": [NSNull()]] as [String: Any]
            case "isBlockhashValid": result = ["context": ["slot": 2], "value": true] as [String: Any]
            default: throw URLError(.unsupportedURL)
            }
            return try JSONSerialization.data(withJSONObject: ["jsonrpc": "2.0", "id": XCTUnwrap(object["id"]), "result": result])
        }
    }
}


extension SendDependencyErrorSurfacingTests {
    @MainActor
    func testSolanaNativePopRejectsRetainedLateOutcome() async throws {
        let context = makeSolanaConfirmPresenter()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let root = UIViewController()
        let navigation = UINavigationController(rootViewController: root)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        let controller = WalletSendConfirmViewController(presenter: context.presenter, localizationManager: LocalizationManager.shared)
        context.presenter.view = controller
        navigation.pushViewController(controller, animated: false)
        window.layoutIfNeeded()
        XCTAssertTrue(navigation.topViewController === controller)
        XCTAssertNotNil(controller.view.window)
        navigation.popViewController(animated: false)
        window.layoutIfNeeded()
        XCTAssertTrue(navigation.topViewController === root)
        XCTAssertNil(controller.view.window)
        context.presenter.didTransfer(result: .success(Self.solanaSignature))
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty)
    }

    @MainActor
    func testSolanaNativeCoveredAndReturnedReviewDoesNotReviveOldOutcome() async throws {
        let context = makeSolanaConfirmPresenter()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let controller = WalletSendConfirmViewController(presenter: context.presenter, localizationManager: LocalizationManager.shared)
        context.presenter.view = controller
        let navigation = UINavigationController(rootViewController: controller)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        window.layoutIfNeeded()
        XCTAssertNotNil(controller.view.window)
        let covering = UIViewController()
        navigation.pushViewController(covering, animated: false)
        window.layoutIfNeeded()
        XCTAssertTrue(navigation.topViewController === covering)
        XCTAssertNil(controller.view.window)
        navigation.popViewController(animated: false)
        window.layoutIfNeeded()
        XCTAssertTrue(navigation.topViewController === controller)
        XCTAssertNotNil(controller.view.window)
        context.presenter.didTransfer(result: .success(Self.solanaSignature))
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty)
    }

    @MainActor
    func testSolanaNativeBackgroundNotificationRevokesOldOutcome() async throws {
        let context = makeSolanaConfirmPresenter()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let controller = WalletSendConfirmViewController(presenter: context.presenter, localizationManager: LocalizationManager.shared)
        context.presenter.view = controller
        window.rootViewController = UINavigationController(rootViewController: controller)
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        window.layoutIfNeeded()
        XCTAssertNotNil(controller.view.window)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        context.presenter.didTransfer(result: .success(Self.solanaSignature))
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty)
    }

    @MainActor
    func testSolanaNativeOwnedRecoverySheetKeepsExplicitRetryAvailable() async throws {
        let context = makeSolanaConfirmPresenter()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let controller = WalletSendConfirmViewController(presenter: context.presenter, localizationManager: LocalizationManager.shared)
        context.presenter.view = controller
        window.rootViewController = UINavigationController(rootViewController: controller)
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        window.layoutIfNeeded()
        context.presenter.didTransfer(result: .failure(TransferServiceError.solanaBroadcastOutcomeUnknown(signature: Self.solanaSignature)))
        let model = try XCTUnwrap(context.wireframe.presentedSheets.last)
        let sheet = SheetAletViewController(viewModel: model)
        sheet.modalPresentationStyle = .custom
        sheet.modalTransitioningFactory = ModalSheetBlurPresentationFactory(configuration: .fearlessBlur)
        await withCheckedContinuation { continuation in controller.present(sheet, animated: false) { continuation.resume() } }
        XCTAssertTrue(controller.presentedViewController === sheet)
        XCTAssertNotNil(sheet.view.window)
        model.actions[0].handler?()
        await withCheckedContinuation { continuation in sheet.dismiss(animated: false) { continuation.resume() } }
        model.dismissCompletion?()
        XCTAssertEqual(context.interactor.retriedHashes, [Self.solanaSignature])
    }
}


extension SendDependencyErrorSurfacingTests {
    @MainActor
    func testSolanaOwnershipFreshExplicitConfirmAfterReturnIsAvailable() {
        let context = makeSolanaConfirmPresenter()
        context.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: 2_000_000_000)), for: context.chainAsset)
        context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 5000)))
        context.presenter.suspendSendReview()
        context.presenter.didTapConfirmButton()
        XCTAssertEqual(context.interactor.submittedCount, 0)
        context.presenter.resumeSendReview()
        context.presenter.didTransfer(result: .success(Self.solanaSignature))
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty)
        context.presenter.didTapConfirmButton()
        context.presenter.didTapConfirmButton()
        XCTAssertEqual(context.interactor.submittedCount, 1)
        context.presenter.didTransfer(result: .success(Self.solanaSignature))
        XCTAssertEqual(context.wireframe.completedHashes, [Self.solanaSignature])
        context.presenter.didTapConfirmButton()
        XCTAssertEqual(context.interactor.submittedCount, 1)
    }

    @MainActor
    func testSolanaOwnershipCurrentFailureAllowsExplicitNewAttempt() throws {
        let context = makeSolanaConfirmPresenter()
        context.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: 2_000_000_000)), for: context.chainAsset)
        context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 5000)))
        context.presenter.didTapConfirmButton()
        XCTAssertEqual(context.interactor.submittedCount, 1)
        context.presenter.didTransfer(result: .failure(TransferServiceError.solanaTransferNotSent(.noConnection)))
        try XCTUnwrap(context.wireframe.presentedSheets.last).dismissCompletion?()
        context.presenter.didTapConfirmButton()
        XCTAssertEqual(context.interactor.submittedCount, 2)
    }

    @MainActor
    func testSolanaPipelineRepeatedAdmissionRetainsOneOwnedTask() async throws {
        let context = try makeSolanaPipeline(hold: .firstGenesis)
        context.interactor.submitExtrinsic()
        await fulfillment(of: [context.transport.entered], timeout: 5)
        let task = try XCTUnwrap(context.interactor.transferTask)
        context.interactor.submitExtrinsic()
        await context.transport.gate.open()
        await task.value
        try await XCTUnwrap(context.interactor.transferTask).value
        XCTAssertEqual(context.keys.reads, 1)
        XCTAssertEqual(context.transport.sent.count, 1)
        XCTAssertEqual(context.wireframe.completedHashes.count, 1)
    }

    @MainActor
    func testSolanaPipelineDepartureDuringPreparationStopsServiceUse() async throws {
        let context = try makeSolanaPipeline(hold: .preparation)
        context.interactor.submitExtrinsic()
        await fulfillment(of: [context.transport.entered], timeout: 5)
        let task = try XCTUnwrap(context.interactor.transferTask)
        context.presenter.didTapBackButton()
        await context.transport.gate.open()
        await task.value
        XCTAssertEqual(context.keys.reads, 0)
        XCTAssertTrue(context.transport.sent.isEmpty)
        XCTAssertEqual(context.store.readState(for: context.scope), .absent)
        XCTAssertTrue(context.wireframe.presentedSheets.isEmpty)
    }

    @MainActor
    func testSolanaPipelineReleasedOwnerCancelsBeforeKeyAccess() async throws {
        var context: SolanaPipelineContext? = try makeSolanaPipeline(hold: .firstGenesis)
        weak var interactor = context?.interactor
        let transport = try XCTUnwrap(context?.transport)
        let keys = try XCTUnwrap(context?.keys)
        let store = try XCTUnwrap(context?.store)
        let scope = try XCTUnwrap(context?.scope)
        context?.interactor.submitExtrinsic()
        await fulfillment(of: [transport.entered], timeout: 5)
        let task = try XCTUnwrap(context?.interactor.transferTask)
        context = nil
        XCTAssertNil(interactor, "Awaited service work must not retain the released interactor")
        await transport.gate.open()
        await task.value
        XCTAssertEqual(keys.reads, 0)
        XCTAssertTrue(transport.sent.isEmpty)
        XCTAssertEqual(store.readState(for: scope), .absent)
    }

    @MainActor
    func testSolanaPipelineReleasedOwnerPreservesAdmittedAcknowledgement() async throws {
        var context: SolanaPipelineContext? = try makeSolanaPipeline(hold: .output)
        weak var interactor = context?.interactor
        let transport = try XCTUnwrap(context?.transport)
        let store = try XCTUnwrap(context?.store)
        let scope = try XCTUnwrap(context?.scope)
        let wireframe = try XCTUnwrap(context?.wireframe)
        context?.interactor.submitExtrinsic()
        await fulfillment(of: [transport.entered], timeout: 5)
        let task = try XCTUnwrap(context?.interactor.transferTask)
        let original = try XCTUnwrap(store.pending(for: scope))
        context = nil
        XCTAssertNil(interactor)
        await transport.gate.open()
        await task.value
        let retained = try XCTUnwrap(store.pending(for: scope))
        XCTAssertEqual(retained.transactionBase64, original.transactionBase64)
        XCTAssertTrue(retained.reportedAsSent)
        XCTAssertEqual(transport.sent, [original.transactionBase64])
        XCTAssertTrue(wireframe.completedHashes.isEmpty)
        XCTAssertTrue(wireframe.presentedSheets.isEmpty)
    }
}


extension SendDependencyErrorSurfacingTests {
    @MainActor
    func testSolanaOwnershipReentrantLoadingDepartureCannotSubmit() {
        let context = makeSolanaConfirmPresenter()
        context.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: 2_000_000_000)), for: context.chainAsset)
        context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 5000)))
        context.view.onStartLoading = { [weak presenter = context.presenter] in presenter?.didTapBackButton() }
        context.presenter.didTapConfirmButton()
        XCTAssertEqual(context.wireframe.closeCount, 1)
        XCTAssertEqual(context.interactor.submittedCount, 0)
    }

    @MainActor
    func testSolanaOwnershipReentrantCompletionDepartureCannotNavigate() {
        let context = makeSolanaConfirmPresenter()
        context.view.onStopLoading = { [weak presenter = context.presenter] in presenter?.didTapBackButton() }
        context.presenter.didTransfer(result: .success(Self.solanaSignature))
        XCTAssertEqual(context.wireframe.closeCount, 1)
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty)
    }

    @MainActor
    func testSolanaOwnershipReentrantRetryDepartureCannotSubmit() throws {
        let context = makeSolanaConfirmPresenter()
        context.presenter.didTransfer(result: .failure(TransferServiceError.solanaBroadcastOutcomeUnknown(signature: Self.solanaSignature)))
        let sheet = try XCTUnwrap(context.wireframe.presentedSheets.last)
        context.view.onStartLoading = { [weak presenter = context.presenter] in presenter?.didTapBackButton() }
        sheet.actions[0].handler?()
        sheet.dismissCompletion?()
        XCTAssertEqual(context.wireframe.closeCount, 1)
        XCTAssertTrue(context.interactor.retriedHashes.isEmpty)
    }
}


extension SendDependencyErrorSurfacingTests {
    @MainActor
    func testSolanaOwnershipCallbackStartedAttemptRejectsEarlierFailureSheet() {
        let context = makeSolanaConfirmPresenter()
        context.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: 2_000_000_000)), for: context.chainAsset)
        context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 5000)))
        context.presenter.didTapConfirmButton()
        XCTAssertEqual(context.interactor.submittedCount, 1)
        context.view.onStopLoading = { [weak presenter = context.presenter] in presenter?.didTapConfirmButton() }
        context.presenter.didTransfer(result: .failure(TransferServiceError.solanaTransferNotSent(.noConnection)))
        XCTAssertEqual(context.interactor.submittedCount, 2, "A fresh current attempt remains usable")
        XCTAssertTrue(context.wireframe.presentedSheets.isEmpty, "Old failure cannot cover the callback-started attempt")
    }

    @MainActor
    func testSolanaOwnershipCallbackStartedRecoveryKeepsItsExactReceipt() throws {
        let context = makeSolanaConfirmPresenter()
        context.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: 2_000_000_000)), for: context.chainAsset)
        context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 5000)))
        context.presenter.didTapConfirmButton()
        context.view.onStopLoading = { [weak presenter = context.presenter, weak view = context.view] in
            view?.onStopLoading = nil
            presenter?.didTapConfirmButton()
            presenter?.didTransfer(result: .failure(TransferServiceError.solanaBroadcastOutcomeUnknown(signature: Self.solanaSignature)))
        }
        context.presenter.didTransfer(result: .failure(TransferServiceError.solanaTransferNotSent(.noConnection)))
        XCTAssertEqual(context.interactor.submittedCount, 2)
        XCTAssertEqual(context.wireframe.presentedSheets.count, 1, "The earlier failure cannot replace the new recovery")
        let recovery = try XCTUnwrap(context.wireframe.presentedSheets.first)
        recovery.actions[0].handler?()
        recovery.dismissCompletion?()
        XCTAssertEqual(context.interactor.retriedHashes, [Self.solanaSignature], "New receipt remains owned")
    }

    @MainActor
    func testSolanaOwnershipSuccessCallbackCannotStartAnotherAttempt() {
        let context = makeSolanaConfirmPresenter()
        context.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: 2_000_000_000)), for: context.chainAsset)
        context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 5000)))
        context.presenter.didTapConfirmButton()
        context.view.onStopLoading = { [weak presenter = context.presenter] in presenter?.didTapConfirmButton() }
        context.presenter.didTransfer(result: .success(Self.solanaSignature))
        XCTAssertEqual(context.interactor.submittedCount, 1)
        XCTAssertEqual(context.wireframe.completedHashes, [Self.solanaSignature])
    }
}


// Selection authority baseline: actual settings save registration/persistence, while the
// asynchronous notification/UI replacement has not revoked the retained confirmation yet.
// The settings/CoreData instance is isolated; no shared/user wallet state is changed. The
// Baseline captured only settings.value. The correction explicitly injects that SAME settings
// instance into the actual interactor; all baseline outcome assertions are preserved.
extension SendDependencyErrorSurfacingTests {
    @MainActor
    func testSolanaSelectionRegisteredBeforeFreshTapRejectsOldWallet() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = try makeSolanaPipeline(hold: .none, selectedWallet: XCTUnwrap(selection.settings.value), selectionSettings: selection.settings)
        try await saveSolanaSelection(selection.other, settings: selection.settings)
        XCTAssertEqual(selection.settings.value?.metaId, selection.other.metaId)
        context.interactor.submitExtrinsic()
        if let task = context.interactor.transferTask { await task.value }
        XCTAssertEqual(context.keys.reads, 0, "A retained old-wallet confirmation must not read keys after selection changes")
        XCTAssertTrue(context.transport.sent.isEmpty)
        XCTAssertEqual(context.store.readState(for: context.scope), .absent)
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty)
    }

    @MainActor
    func testSolanaSelectionRegisteredDuringRpcRejectsOldKeysBeforeSaveAcknowledgement() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = try makeSolanaPipeline(hold: .firstGenesis, selectedWallet: XCTUnwrap(selection.settings.value), selectionSettings: selection.settings)
        context.interactor.submitExtrinsic()
        await fulfillment(of: [context.transport.entered], timeout: 5)
        let task = try XCTUnwrap(context.interactor.transferTask)
        let saved = expectation(description: "actual selection persistence eventually acknowledges")
        var acknowledged = false
        selection.settings.operationQueue.isSuspended = true
        defer { selection.settings.operationQueue.isSuspended = false }
        selection.settings.save(value: selection.other, runningCompletionIn: .main) { result in
            if case let .failure(error) = result { XCTFail("Unexpected selection save error: \(error)") }
            acknowledged = true
            saved.fulfill()
        }
        XCTAssertEqual(selection.settings.value?.metaId, selection.other.metaId)
        XCTAssertFalse(acknowledged, "Save is registered but its real operation queue is held")
        XCTAssertEqual(context.keys.reads, 0)
        await context.transport.gate.open()
        await task.value
        XCTAssertEqual(context.keys.reads, 0, "Selection registration must revoke old work before deferred UIKit notification")
        XCTAssertTrue(context.transport.sent.isEmpty)
        XCTAssertEqual(context.store.readState(for: context.scope), .absent)
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty)
        selection.settings.operationQueue.isSuspended = false
        await fulfillment(of: [saved], timeout: 5)
        XCTAssertTrue(acknowledged)
    }

    @MainActor
    func testSolanaSelectionAcknowledgedWithEventDeliveryHeldRejectsOldKeys() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = try makeSolanaPipeline(hold: .firstGenesis, selectedWallet: XCTUnwrap(selection.settings.value), selectionSettings: selection.settings)
        let notice = SelectionNoticeBlocker()
        defer { notice.release() }
        context.interactor.submitExtrinsic()
        await fulfillment(of: [context.transport.entered], timeout: 5)
        let task = try XCTUnwrap(context.interactor.transferTask)
        try await saveSolanaSelection(selection.other, settings: selection.settings, eventCenter: notice.center)
        XCTAssertEqual(selection.settings.value?.metaId, selection.other.metaId)
        XCTAssertEqual(notice.recorder.count, 0, "The real EventCenter has not delivered the registered selection")
        await context.transport.gate.open()
        await task.value
        XCTAssertEqual(context.keys.reads, 0)
        XCTAssertTrue(context.transport.sent.isEmpty)
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty)
        notice.release()
        await fulfillment(of: [notice.recorder.delivered], timeout: 5)
        XCTAssertEqual(notice.recorder.count, 1)
    }

    @MainActor
    func testSolanaSelectionAtoBtoAInvalidatesEarlierAReview() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = try makeSolanaPipeline(hold: .firstGenesis, selectedWallet: XCTUnwrap(selection.settings.value), selectionSettings: selection.settings)
        context.interactor.submitExtrinsic()
        await fulfillment(of: [context.transport.entered], timeout: 5)
        let task = try XCTUnwrap(context.interactor.transferTask)
        try await saveSolanaSelection(selection.other, settings: selection.settings)
        try await saveSolanaSelection(selection.original, settings: selection.settings)
        XCTAssertEqual(selection.settings.value?.metaId, selection.original.metaId)
        XCTAssertEqual(context.keys.reads, 0)
        await context.transport.gate.open()
        await task.value
        XCTAssertEqual(context.keys.reads, 0, "Current wallet equality must not revive an obsolete review")
        XCTAssertTrue(context.transport.sent.isEmpty)
        XCTAssertEqual(context.store.readState(for: context.scope), .absent)
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty)
    }

    @MainActor
    func testSolanaSelectionAfterAdmittedOutputKeepsJournalButRejectsOldUi() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = try makeSolanaPipeline(hold: .output, selectedWallet: XCTUnwrap(selection.settings.value), selectionSettings: selection.settings)
        context.interactor.submitExtrinsic()
        await fulfillment(of: [context.transport.entered], timeout: 5)
        let task = try XCTUnwrap(context.interactor.transferTask)
        let pending = try XCTUnwrap(context.store.pending(for: context.scope))
        XCTAssertEqual(context.transport.sent, [pending.transactionBase64])
        try await saveSolanaSelection(selection.other, settings: selection.settings)
        await context.transport.gate.open()
        await task.value
        let retained = try XCTUnwrap(context.store.pending(for: context.scope))
        XCTAssertEqual(retained.transactionBase64, pending.transactionBase64)
        XCTAssertEqual(retained.signature, pending.signature)
        XCTAssertTrue(retained.reportedAsSent)
        XCTAssertEqual(context.transport.sent, [pending.transactionBase64])
        XCTAssertEqual(context.keys.reads, 1)
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty, "Selection suppresses obsolete UI, never erases already admitted output")
        XCTAssertTrue(context.wireframe.presentedSheets.isEmpty)
    }

    @MainActor
    func testSolanaSelectionRejectsRetainedRecoveryRetryWithoutErasingPending() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = try makeSolanaPipeline(hold: .none, selectedWallet: XCTUnwrap(selection.settings.value), selectionSettings: selection.settings)
        context.transport.loseResponse = true
        context.interactor.submitExtrinsic()
        try await XCTUnwrap(context.interactor.transferTask).value
        let pending = try XCTUnwrap(context.store.pending(for: context.scope))
        let sheet = try XCTUnwrap(context.wireframe.presentedSheets.last)
        try await saveSolanaSelection(selection.other, settings: selection.settings)
        sheet.actions[0].handler?()
        sheet.dismissCompletion?()
        try await XCTUnwrap(context.interactor.transferTask).value
        XCTAssertEqual(context.transport.sent, [pending.transactionBase64], "Retained old-wallet retry must not authorize another output")
        XCTAssertEqual(context.store.pending(for: context.scope), pending)
        XCTAssertEqual(context.keys.reads, 1)
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty)
    }

    @MainActor
    func testSolanaSelectionUnchangedCurrentWalletStillCompletesOnce() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = try makeSolanaPipeline(hold: .firstGenesis, selectedWallet: XCTUnwrap(selection.settings.value), selectionSettings: selection.settings)
        context.interactor.submitExtrinsic()
        await fulfillment(of: [context.transport.entered], timeout: 5)
        let task = try XCTUnwrap(context.interactor.transferTask)
        XCTAssertEqual(selection.settings.value?.metaId, selection.original.metaId)
        await context.transport.gate.open()
        await task.value
        let pending = try XCTUnwrap(context.store.pending(for: context.scope))
        XCTAssertEqual(context.keys.reads, 1)
        XCTAssertEqual(context.transport.sent, [pending.transactionBase64])
        XCTAssertTrue(pending.reportedAsSent)
        XCTAssertEqual(context.wireframe.completedHashes, [pending.signature])
    }

    @MainActor
    func testSolanaSelectionFreshReviewAfterAtoBtoAStillCompletesOnce() async throws {
        let selection = try await makeSolanaSelectionFixture()
        try await saveSolanaSelection(selection.other, settings: selection.settings)
        try await saveSolanaSelection(selection.original, settings: selection.settings)
        let context = try makeSolanaPipeline(hold: .none, selectedWallet: XCTUnwrap(selection.settings.value), selectionSettings: selection.settings)
        context.interactor.submitExtrinsic()
        try await XCTUnwrap(context.interactor.transferTask).value
        let pending = try XCTUnwrap(context.store.pending(for: context.scope))
        XCTAssertEqual(context.keys.reads, 1)
        XCTAssertEqual(context.transport.sent, [pending.transactionBase64])
        XCTAssertTrue(pending.reportedAsSent)
        XCTAssertEqual(context.wireframe.completedHashes, [pending.signature])
    }

    private struct SolanaSelectionFixture {
        let settings: SelectedWalletSettings
        let original: MetaAccountModel
        let other: MetaAccountModel
    }

    @MainActor
    private func makeSolanaSelectionFixture() async throws -> SolanaSelectionFixture {
        let account = try SolanaKeyDerivation.deriveAccount(mnemonic: SolanaPipelineKeys.phrase)
        let chainAccount = ChainAccountModel(chainId: Self.solanaChain.chainId, accountId: account.publicKey,
            publicKey: account.publicKey, cryptoType: CryptoType.ed25519.rawValue, ethereumBased: false)
        let original = AccountGenerator.generateMetaAccount(with: [chainAccount])
        // Identical public account in two distinct wallets is intentional: exact wallet identity,
        // not just address equality, owns the review. Neither wallet uses the user keychain.
        let other = AccountGenerator.generateMetaAccount(with: [chainAccount])
        let settings = SelectedWalletSettings(storageFacade: UserDataStorageTestFacade(), operationQueue: OperationQueue())
        try await saveSolanaSelection(original, settings: settings)
        XCTAssertEqual(settings.value?.metaId, original.metaId)
        XCTAssertNotEqual(original.metaId, other.metaId)
        return SolanaSelectionFixture(settings: settings, original: original, other: other)
    }

    @MainActor
    private func saveSolanaSelection(_ wallet: MetaAccountModel, settings: SelectedWalletSettings,
                                     eventCenter: EventCenter? = nil) async throws {
        let saved: MetaAccountModel = try await withCheckedThrowingContinuation { continuation in
            settings.save(value: wallet, runningCompletionIn: .main) { result in
                if case let .success(account) = result { eventCenter?.notify(with: SelectedAccountChanged(account: account)) }
                continuation.resume(with: result)
            }
        }
        XCTAssertEqual(saved.metaId, wallet.metaId)
    }

    private final class SelectionNoticeRecorder: EventVisitorProtocol {
        let delivered = XCTestExpectation(description: "real deferred selection notification")
        private let lock = NSLock()
        private var received = 0
        var count: Int { lock.lock(); defer { lock.unlock() }; return received }
        func processSelectedAccountChanged(event _: SelectedAccountChanged) {
            lock.lock(); received += 1; lock.unlock()
            delivered.fulfill()
        }
    }

    private final class SelectionNoticeBlocker {
        let queue: DispatchQueue
        let center: EventCenter
        let recorder = SelectionNoticeRecorder()
        private var blocked = true
        init() {
            let eventQueue = DispatchQueue(label: "public-selection-event-held")
            queue = eventQueue
            center = EventCenter(syncQueue: eventQueue)
            center.add(observer: recorder, dispatchIn: nil)
            queue.sync {} // Register the actual observer before holding delivery, without sleeps.
            queue.suspend()
        }
        func release() {
            guard blocked else { return }
            blocked = false
            queue.resume()
        }
        deinit { release() }
    }
}

extension SendDependencyErrorSurfacingTests {
    @MainActor
    func testSolanaSelectionUnrelatedSettingsCannotRevokeCurrentPipeline() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let unrelated = try await makeSolanaSelectionFixture()
        let context = try makeSolanaPipeline(hold: .firstGenesis, selectedWallet: selection.original,
                                             selectionSettings: selection.settings)
        context.interactor.submitExtrinsic()
        await fulfillment(of: [context.transport.entered], timeout: 5)
        try await saveSolanaSelection(unrelated.other, settings: unrelated.settings)
        await context.transport.gate.open()
        try await XCTUnwrap(context.interactor.transferTask).value
        let pending = try XCTUnwrap(context.store.pending(for: context.scope))
        XCTAssertEqual(context.keys.reads, 1)
        XCTAssertEqual(context.transport.sent, [pending.transactionBase64])
        XCTAssertEqual(context.wireframe.completedHashes, [pending.signature])
    }

    @MainActor
    func testSolanaSelectionIdentitySafeRenameAndBackupKeepCurrentPipeline() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = try makeSolanaPipeline(hold: .firstGenesis, selectedWallet: selection.original,
                                             selectionSettings: selection.settings)
        context.interactor.submitExtrinsic()
        await fulfillment(of: [context.transport.entered], timeout: 5)
        try await saveSolanaSelection(selection.original.replacingName("Public renamed wallet").replacingIsBackuped(true),
                                      settings: selection.settings)
        XCTAssertEqual(selection.settings.value?.name, "Public renamed wallet")
        XCTAssertTrue(try XCTUnwrap(selection.settings.value).hasBackup)
        await context.transport.gate.open()
        try await XCTUnwrap(context.interactor.transferTask).value
        let pending = try XCTUnwrap(context.store.pending(for: context.scope))
        XCTAssertEqual(context.keys.reads, 1)
        XCTAssertEqual(context.transport.sent, [pending.transactionBase64])
        XCTAssertEqual(context.wireframe.completedHashes, [pending.signature])
    }

    @MainActor
    func testSolanaSelectionSameIdChangedAccountRevokesBeforeAcknowledgement() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = try makeSolanaPipeline(hold: .firstGenesis, selectedWallet: selection.original,
                                             selectionSettings: selection.settings)
        let account = ChainAccountModel(chainId: Self.solanaChain.chainId, accountId: Data(repeating: 9, count: 32),
            publicKey: Data(repeating: 9, count: 32), cryptoType: CryptoType.ed25519.rawValue, ethereumBased: false)
        let changed = selection.original.replacingChainAccounts([account])
        XCTAssertEqual(changed.metaId, selection.original.metaId)
        XCTAssertNotEqual(changed.chainAccounts, selection.original.chainAccounts)
        context.interactor.submitExtrinsic()
        await fulfillment(of: [context.transport.entered], timeout: 5)
        selection.settings.operationQueue.isSuspended = true
        defer { selection.settings.operationQueue.isSuspended = false }
        let acknowledged = expectation(description: "same-id save drains after held key check")
        selection.settings.save(value: changed, runningCompletionIn: .main) { _ in acknowledged.fulfill() }
        XCTAssertEqual(selection.settings.value?.chainAccounts, changed.chainAccounts)
        await context.transport.gate.open()
        try await XCTUnwrap(context.interactor.transferTask).value
        XCTAssertEqual(context.keys.reads, 0)
        XCTAssertTrue(context.transport.sent.isEmpty)
        XCTAssertEqual(context.store.readState(for: context.scope), .absent)
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty)
        selection.settings.operationQueue.isSuspended = false
        await fulfillment(of: [acknowledged], timeout: 5)
        XCTAssertFalse(context.interactor.isSendSelectionCurrent, "Persistence may restore original accounts; that cannot revive the old revision")
    }

    @MainActor
    func testSolanaSelectionSameIdChangedRootKeyRevokesLease() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let lease = selection.settings.sendAuthority.capture(for: selection.original)
        let changed = selection.original.replacingEthereumPublicKey(Data(repeating: 7, count: 33))
        XCTAssertEqual(changed.metaId, selection.original.metaId)
        selection.settings.applySetupResult(.success(changed))
        XCTAssertFalse(lease.isCurrent)
        XCTAssertThrowsError(try lease.requireCurrent()) { XCTAssertTrue($0 is CancellationError) }
        selection.settings.applySetupResult(.success(selection.original))
        XCTAssertFalse(lease.isCurrent)
        XCTAssertTrue(selection.settings.sendAuthority.capture(for: selection.original).isCurrent)
    }

    @MainActor
    func testSolanaSelectionFailedSaveRollbackDoesNotReviveEarlierReview() async throws {
        let source = try await makeSolanaSelectionFixture()
        let storage = SelectionFailingStorage()
        let settings = SelectedWalletSettings(storageFacade: storage, operationQueue: OperationQueue())
        try await saveSolanaSelection(source.original, settings: settings)
        let context = try makeSolanaPipeline(hold: .firstGenesis, selectedWallet: source.original, selectionSettings: settings)
        context.interactor.submitExtrinsic()
        await fulfillment(of: [context.transport.entered], timeout: 5)
        storage.failRequests = true
        do {
            try await saveSolanaSelection(source.other, settings: settings)
            XCTFail("The actual repository request must fail")
        } catch { XCTAssertEqual((error as NSError).domain, "public-selection-storage-fault") }
        XCTAssertEqual(settings.value, source.original, "Actual PersistentValueSettings completion rolls back to committed A")
        await context.transport.gate.open()
        try await XCTUnwrap(context.interactor.transferTask).value
        XCTAssertEqual(context.keys.reads, 0)
        XCTAssertTrue(context.transport.sent.isEmpty)
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty)
        storage.failRequests = false
        let fresh = try makeSolanaPipeline(hold: .none, selectedWallet: source.original, selectionSettings: settings)
        fresh.interactor.submitExtrinsic()
        try await XCTUnwrap(fresh.interactor.transferTask).value
        XCTAssertEqual(fresh.keys.reads, 1)
        XCTAssertEqual(fresh.transport.sent.count, 1)
        XCTAssertEqual(fresh.wireframe.completedHashes.count, 1)
    }

    @MainActor
    func testSolanaSelectionDuringFinalAttestationStopsNewOutput() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = try makeSolanaPipeline(hold: .sendGenesis, selectedWallet: selection.original,
                                             selectionSettings: selection.settings)
        context.interactor.submitExtrinsic()
        await fulfillment(of: [context.transport.entered], timeout: 5)
        XCTAssertEqual(context.keys.reads, 1)
        XCTAssertEqual(context.transport.simulations, 1)
        XCTAssertTrue(context.transport.sent.isEmpty)
        let pending = try XCTUnwrap(context.store.pending(for: context.scope))
        XCTAssertFalse(pending.reportedAsSent)
        try await saveSolanaSelection(selection.other, settings: selection.settings)
        await context.transport.gate.open()
        try await XCTUnwrap(context.interactor.transferTask).value
        XCTAssertTrue(context.transport.sent.isEmpty)
        XCTAssertEqual(context.store.pending(for: context.scope), pending, "Cancellation remains conservatively ambiguous; exact unreported bytes survive")
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty)
        XCTAssertTrue(context.wireframe.presentedSheets.isEmpty)
    }

    @MainActor
    func testSolanaSelectionOutputHoldDoesNotBlockSelectionPersistence() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = try makeSolanaPipeline(hold: .output, selectedWallet: selection.original,
                                             selectionSettings: selection.settings)
        context.interactor.submitExtrinsic()
        await fulfillment(of: [context.transport.entered], timeout: 5)
        let pending = try XCTUnwrap(context.store.pending(for: context.scope))
        let acknowledged = expectation(description: "selection acknowledges while output remains held")
        selection.settings.save(value: selection.other, runningCompletionIn: .main) { result in
            if case let .failure(error) = result { XCTFail("\(error)") }
            acknowledged.fulfill()
        }
        await fulfillment(of: [acknowledged], timeout: 5)
        XCTAssertEqual(selection.settings.value?.metaId, selection.other.metaId)
        XCTAssertEqual(context.store.pending(for: context.scope), pending)
        await context.transport.gate.open()
        try await XCTUnwrap(context.interactor.transferTask).value
        let retained = try XCTUnwrap(context.store.pending(for: context.scope))
        XCTAssertEqual(retained.transactionBase64, pending.transactionBase64)
        XCTAssertTrue(retained.reportedAsSent)
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty)
    }

    @MainActor
    func testSolanaSelectionLoadingCallbackRevokesBeforeActualSubmit() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = try makeSolanaPipeline(hold: .none, selectedWallet: selection.original,
                                             selectionSettings: selection.settings)
        context.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: 2_000_000_000)),
                                                 for: ChainAsset(chain: Self.solanaChain, asset: Self.solAsset))
        context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 5000)))
        context.view.onStartLoading = { selection.settings.applySetupResult(.success(selection.other)) }
        context.presenter.didTapConfirmButton()
        if let task = context.interactor.transferTask { await task.value }
        XCTAssertEqual(selection.settings.value?.metaId, selection.other.metaId)
        XCTAssertEqual(context.keys.reads, 0)
        XCTAssertTrue(context.transport.sent.isEmpty)
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty)
    }

    private final class SelectionFailingStorage: UserDataStorageTestFacade {
        var failRequests = false
        override func createRepository<T: Identifiable, U: NSManagedObject>(
            filter: NSPredicate?, sortDescriptors: [NSSortDescriptor], mapper: AnyCoreDataMapper<T, U>
        ) -> CoreDataRepository<T, U> {
            guard failRequests else { return super.createRepository(filter: filter, sortDescriptors: sortDescriptors, mapper: mapper) }
            return CoreDataRepository(databaseService: SelectionFailedDatabase(configuration: databaseService.configuration),
                                      mapper: mapper, filter: filter, sortDescriptors: sortDescriptors)
        }
    }

    private final class SelectionFailedDatabase: CoreDataServiceProtocol {
        let configuration: CoreDataServiceConfigurationProtocol
        init(configuration: CoreDataServiceConfigurationProtocol) { self.configuration = configuration }
        func performAsync(block: @escaping CoreDataContextInvocationBlock) {
            block(nil, NSError(domain: "public-selection-storage-fault", code: 1))
        }
        func close() throws {}
        func drop() throws {}
    }
}

extension SendDependencyErrorSurfacingTests {
    @MainActor
    func testSolanaSelectionDuringHeldRetainedReadRejectsOldKeys() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let read = SolanaPipelineReadHold()
        defer { read.release() }
        let context = try makeSolanaPipeline(hold: .none, selectedWallet: selection.original,
                                             selectionSettings: selection.settings, retainedRead: read)
        context.interactor.submitExtrinsic()
        await fulfillment(of: [read.entered], timeout: 5)
        XCTAssertEqual(read.calls, 3, "Actual retained-state read follows the two initial recovery reads")
        XCTAssertEqual(context.keys.reads, 0)
        try await saveSolanaSelection(selection.other, settings: selection.settings)
        XCTAssertEqual(selection.settings.value?.metaId, selection.other.metaId)
        read.release()
        try await XCTUnwrap(context.interactor.transferTask).value
        XCTAssertEqual(context.keys.reads, 0, "Selection changed while synchronous retained-state I/O was held")
        XCTAssertTrue(context.transport.sent.isEmpty)
        XCTAssertEqual(context.store.readState(for: context.scope), .absent)
        XCTAssertTrue(context.wireframe.completedHashes.isEmpty)
    }

    @MainActor
    func testSolanaSelectionHeldRetainedReadCurrentWalletCompletes() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let read = SolanaPipelineReadHold()
        defer { read.release() }
        let context = try makeSolanaPipeline(hold: .none, selectedWallet: selection.original,
                                             selectionSettings: selection.settings, retainedRead: read)
        context.interactor.submitExtrinsic()
        await fulfillment(of: [read.entered], timeout: 5)
        XCTAssertEqual(read.calls, 3)
        XCTAssertEqual(context.keys.reads, 0)
        read.release()
        try await XCTUnwrap(context.interactor.transferTask).value
        let pending = try XCTUnwrap(context.store.pending(for: context.scope))
        XCTAssertEqual(context.keys.reads, 1)
        XCTAssertEqual(context.transport.sent, [pending.transactionBase64])
        XCTAssertEqual(context.wireframe.completedHashes, [pending.signature])
    }

    private final class SolanaPipelineReadHold {
        let entered = XCTestExpectation(description: "actual post-attestation store read held")
        private let condition = NSCondition()
        private var count = 0
        private var released = false
        var calls: Int { condition.lock(); defer { condition.unlock() }; return count }
        func didRead() throws {
            condition.lock()
            defer { condition.unlock() }
            count += 1
            guard count == 3 else { return }
            entered.fulfill()
            let deadline = Date().addingTimeInterval(15)
            while !released {
                guard condition.wait(until: deadline) else {
                    throw NSError(domain: "held-retained-read-timeout", code: 1)
                }
            }
        }
        func release() { condition.lock(); released = true; condition.broadcast(); condition.unlock() }
    }

    /// The original store still performs every snapshot and durable mutation. Only the
    /// synchronous return from its third actual snapshot is held; no fake absence/result.
    private final class HeldSolanaPipelineStore: SolanaPendingBroadcastStoring {
        let store: SolanaPendingBroadcastStore
        let hold: SolanaPipelineReadHold
        init(store: SolanaPendingBroadcastStore, hold: SolanaPipelineReadHold) { self.store = store; self.hold = hold }
        func snapshot(for scope: SolanaPendingBroadcastScope) throws -> SolanaPendingBroadcastSnapshot? {
            let value = try store.snapshot(for: scope)
            try hold.didRead()
            return value
        }
        func pending(for scope: SolanaPendingBroadcastScope) -> SolanaPendingBroadcast? { store.pending(for: scope) }
        func readState(for scope: SolanaPendingBroadcastScope) -> SolanaPendingBroadcastReadState { store.readState(for: scope) }
        func save(_ record: SolanaPendingBroadcast, for scope: SolanaPendingBroadcastScope) throws { try store.save(record, for: scope) }
        func admit(_ record: SolanaPendingBroadcast, for scope: SolanaPendingBroadcastScope) throws -> SolanaPendingBroadcastSnapshot {
            try store.admit(record, for: scope)
        }
        func markReported(_ expected: SolanaPendingBroadcastSnapshot, for scope: SolanaPendingBroadcastScope) throws -> Bool {
            try store.markReported(expected, for: scope)
        }
        func clear(_ expected: SolanaPendingBroadcastSnapshot, for scope: SolanaPendingBroadcastScope) -> Bool { store.clear(expected, for: scope) }
        func clear(signature: String, for scope: SolanaPendingBroadcastScope) { store.clear(signature: signature, for: scope) }
    }
}

// Actual SendPresenter + DataValidationRunner with isolated real wallet settings and public inputs.
// This baseline supplies the selected wallet value; no settings authority is wired into Send yet.
extension SendDependencyErrorSurfacingTests {
    @MainActor
    func testSolanaFormCurrentSelectionOpensExactConfirmation() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection)
        context.presenter.didTapContinueButton()
        XCTAssertEqual(context.router.confirmations.count, 1)
        let confirmation = try XCTUnwrap(context.router.confirmations.first)
        XCTAssertEqual(confirmation.wallet.metaId, selection.original.metaId)
        XCTAssertEqual(confirmation.asset.assetKey, context.chainAsset.assetKey)
        XCTAssertEqual(confirmation.call.amount, BigUInt(20_000_000))
        XCTAssertEqual(confirmation.call.receiverAddress, Self.formRecipient)
    }

    @MainActor
    func testSolanaFormOldWalletCannotOpenConfirmationAfterSelectionChange() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection)
        try await saveSolanaSelection(selection.other, settings: selection.settings)
        context.presenter.didTapContinueButton()
        XCTAssertTrue(context.router.confirmations.isEmpty)
    }

    @MainActor
    func testSolanaFormAtoBtoACannotReviveOldForm() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection)
        try await saveSolanaSelection(selection.other, settings: selection.settings)
        try await saveSolanaSelection(selection.original, settings: selection.settings)
        context.presenter.didTapContinueButton()
        XCTAssertTrue(context.router.confirmations.isEmpty)
    }

    @MainActor
    func testSolanaFormFreshFormAfterAtoBtoARemainsUsable() async throws {
        let selection = try await makeSolanaSelectionFixture()
        try await saveSolanaSelection(selection.other, settings: selection.settings)
        try await saveSolanaSelection(selection.original, settings: selection.settings)
        let context = makeSolanaForm(selection: selection)
        context.presenter.didTapContinueButton()
        XCTAssertEqual(context.router.confirmations.count, 1)
    }

    @MainActor
    func testSolanaFormCurrentSameAddressWarningCanProceed() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection)
        let proceed = try retainedFormProceed(context)
        proceed()
        XCTAssertEqual(context.router.confirmations.count, 1)
        XCTAssertEqual(context.router.confirmations.first?.call.receiverAddress, Self.formRecipient)
    }

    @MainActor
    func testSolanaFormRetainedWarningCannotSurviveWalletSelection() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection)
        let proceed = try retainedFormProceed(context)
        try await saveSolanaSelection(selection.other, settings: selection.settings)
        proceed()
        XCTAssertTrue(context.router.confirmations.isEmpty)
    }

    @MainActor
    func testSolanaFormRetainedWarningCannotAdoptChangedAmount() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection)
        let proceed = try retainedFormProceed(context)
        context.presenter.updateAmount(0.03)
        proceed()
        XCTAssertTrue(context.router.confirmations.isEmpty)
    }

    @MainActor
    func testSolanaFormRetainedWarningCannotUsePreviousRecipient() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection)
        let proceed = try retainedFormProceed(context)
        context.presenter.searchTextDidChanged("11111111111111111111111111111111")
        proceed()
        XCTAssertTrue(context.router.confirmations.isEmpty)
    }

    @MainActor
    func testSolanaFormRetainedWarningCannotSurviveAssetAtoBtoA() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection)
        let proceed = try retainedFormProceed(context)
        context.presenter.assetSelection(didCompleteWith: ChainAsset(chain: Self.bitcoinChain, asset: Self.btcAsset), contextTag: nil)
        context.presenter.assetSelection(didCompleteWith: context.chainAsset, contextTag: nil)
        prepareSolanaFormValues(context)
        proceed()
        XCTAssertTrue(context.router.confirmations.isEmpty)
    }

    @MainActor
    func testSolanaFormRetainedWarningCannotOpenAfterBack() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection)
        let proceed = try retainedFormProceed(context)
        context.presenter.didTapBackButton()
        XCTAssertEqual(context.router.dismissCount, 1)
        proceed()
        XCTAssertTrue(context.router.confirmations.isEmpty)
    }

    @MainActor
    func testSolanaFormRetainedProceedIsConsumedOnce() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection)
        let proceed = try retainedFormProceed(context)
        proceed(); proceed()
        XCTAssertEqual(context.router.confirmations.count, 1)
    }

    @MainActor
    func testSolanaFormRetainedWarningCannotAdoptNewFee() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection)
        let proceed = try retainedFormProceed(context)
        context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 9_000)))
        proceed()
        XCTAssertTrue(context.router.confirmations.isEmpty)
    }

    @MainActor
    func testSolanaFormRetainedWarningCannotAdoptNewTip() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection)
        let proceed = try retainedFormProceed(context)
        context.presenter.didReceiveTip(result: .success(BigUInt(10_000)))
        proceed()
        XCTAssertTrue(context.router.confirmations.isEmpty)
    }

    @MainActor
    func testSolanaFormRetainedWarningCannotAdoptChangedBalance() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection)
        let proceed = try retainedFormProceed(context)
        context.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: BigUInt(9_000_000_000))), for: context.chainAsset)
        proceed()
        XCTAssertTrue(context.router.confirmations.isEmpty)
    }

    private static let formRecipient = "7UX3yVP9p1hbB9vqw7F6hDc9S4HGf6rSHaN8Zb6HiVQ2"

    @MainActor
    private func makeSolanaForm(selection: SolanaSelectionFixture, bindValidationView: Bool = false) -> PresenterContext {
        let asset = ChainAsset(chain: Self.solanaChain, asset: Self.solAsset)
        let interactor = SendInteractorStub(container: Self.productionContainer())
        interactor.validationOverride = .valid(Self.formRecipient)
        let router = SendRouterSpy()
        let view = SendViewStub()
        let validating = SendDataValidatingFactory(presentable: router)
        if bindValidationView { validating.view = view }
        let presenter = SendPresenter(interactor: interactor, router: router,
            localizationManager: LocalizationManager.shared, viewModelFactory: SendViewModelFactoryStub(),
            dataValidatingFactory: validating, wallet: selection.original, initialData: .chainAsset(asset),
            selectedWalletSettings: selection.settings)
        presenter.didLoad(view: view)
        let context = PresenterContext(presenter: presenter, interactor: interactor, router: router, view: view, chainAsset: asset, validating: validating)
        presenter.searchTextDidChanged(Self.formRecipient)
        prepareSolanaFormValues(context)
        return context
    }

    @MainActor
    private func prepareSolanaFormValues(_ context: PresenterContext) {
        context.presenter.didReceiveAssetAccountInfo(assetAccountInfo: nil)
        context.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: BigUInt(10_000_000_000))), for: context.chainAsset)
        context.presenter.didReceiveMinimumBalance(result: .success(.zero))
        context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 5_000)))
        context.presenter.updateAmount(0.02)
    }

    @MainActor
    private func retainedFormProceed(_ context: PresenterContext) throws -> () -> Void {
        context.interactor.validationOverride = .sameAddress(Self.formRecipient)
        context.presenter.didTapContinueButton()
        XCTAssertTrue(context.router.confirmations.isEmpty)
        let sheet = try XCTUnwrap(context.router.presentedSheets.last)
        XCTAssertEqual(sheet.actions.count, 1)
        return try XCTUnwrap(sheet.actions.first?.handler)
    }
}


extension SendDependencyErrorSurfacingTests {
    @MainActor
    func testSolanaFormNativePopRevokesRetainedWarning() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let proceed = try retainedFormProceed(native.context)
        native.navigation.popViewController(animated: false)
        native.window.layoutIfNeeded()
        XCTAssertTrue(native.navigation.topViewController === native.root)
        XCTAssertNil(native.controller.view.window)
        proceed()
        XCTAssertTrue(native.context.router.confirmations.isEmpty)
    }

    @MainActor
    func testSolanaFormNativeCoverReturnRevokesOldWarningAndAllowsFreshContinue() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let proceed = try retainedFormProceed(native.context)
        let cover = UIViewController()
        native.navigation.pushViewController(cover, animated: false)
        native.window.layoutIfNeeded()
        XCTAssertNil(native.controller.view.window)
        native.navigation.popViewController(animated: false)
        native.window.layoutIfNeeded()
        XCTAssertTrue(native.navigation.topViewController === native.controller)
        XCTAssertNotNil(native.controller.view.window)
        proceed()
        let obsoleteRoutes = native.context.router.confirmations.count
        native.context.interactor.validationOverride = .valid(Self.formRecipient)
        native.context.presenter.didTapContinueButton()
        XCTAssertEqual(native.context.router.confirmations.count, obsoleteRoutes + 1)
        XCTAssertEqual(obsoleteRoutes, 0)
    }

    @MainActor
    func testSolanaFormNativeBackgroundReturnRevokesOldWarningAndAllowsFreshContinue() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let proceed = try retainedFormProceed(native.context)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        proceed()
        let obsoleteRoutes = native.context.router.confirmations.count
        native.context.interactor.validationOverride = .valid(Self.formRecipient)
        native.context.presenter.didTapContinueButton()
        XCTAssertEqual(native.context.router.confirmations.count, obsoleteRoutes + 1)
        XCTAssertEqual(obsoleteRoutes, 0)
    }

    @MainActor
    func testSolanaFormNativeBackgroundRejectsNewContinueUntilActive() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        native.context.presenter.didTapContinueButton()
        let backgroundRoutes = native.context.router.confirmations.count
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        native.context.presenter.didTapContinueButton()
        XCTAssertEqual(native.context.router.confirmations.count, backgroundRoutes + 1)
        XCTAssertEqual(backgroundRoutes, 0)
    }

    @MainActor
    func testSolanaFormNativeOwnedWarningKeepsProceedAvailable() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let proceed = try retainedFormProceed(native.context)
        let model = try XCTUnwrap(native.context.router.presentedSheets.last)
        let sheet = SheetAletViewController(viewModel: model, externalDismissalCompletion: model.dismissCompletion)
        sheet.modalPresentationStyle = .custom
        sheet.modalTransitioningFactory = ModalSheetBlurPresentationFactory(configuration: .fearlessBlur)
        await withCheckedContinuation { continuation in
            native.controller.present(sheet, animated: false) { continuation.resume() }
        }
        XCTAssertTrue(native.controller.presentedViewController === sheet)
        XCTAssertNotNil(sheet.view.window)
        proceed()
        await withCheckedContinuation { continuation in
            sheet.dismiss(animated: false) { continuation.resume() }
        }
        XCTAssertEqual(native.context.router.confirmations.count, 1)
    }

    @MainActor
    func testSolanaFormNativeDismissedWarningCannotProceedLater() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let proceed = try retainedFormProceed(native.context)
        let model = try XCTUnwrap(native.context.router.presentedSheets.last)
        let sheet = SheetAletViewController(viewModel: model, externalDismissalCompletion: model.dismissCompletion)
        sheet.modalPresentationStyle = .custom
        sheet.modalTransitioningFactory = ModalSheetBlurPresentationFactory(configuration: .fearlessBlur)
        await withCheckedContinuation { continuation in
            native.controller.present(sheet, animated: false) { continuation.resume() }
        }
        XCTAssertNotNil(sheet.view.window)
        await withCheckedContinuation { continuation in
            sheet.dismiss(animated: false) { continuation.resume() }
        }
        XCTAssertNil(native.controller.presentedViewController)
        proceed()
        let obsoleteRoutes = native.context.router.confirmations.count
        native.context.interactor.validationOverride = .valid(Self.formRecipient)
        native.context.presenter.didTapContinueButton()
        XCTAssertEqual(native.context.router.confirmations.count, obsoleteRoutes + 1)
        XCTAssertEqual(obsoleteRoutes, 0)
    }

    @MainActor
    private func makeNativeSolanaForm(selection: SolanaSelectionFixture, bindValidationView: Bool = false) throws -> NativeSolanaForm {
        let context = makeSolanaForm(selection: selection, bindValidationView: bindValidationView)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let root = UIViewController()
        let navigation = UINavigationController(rootViewController: root)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        let controller = SendViewController(initialData: .chainAsset(context.chainAsset), output: context.presenter,
            localizationManager: LocalizationManager.shared)
        navigation.pushViewController(controller, animated: false)
        window.layoutIfNeeded()
        XCTAssertTrue(navigation.topViewController === controller)
        XCTAssertNotNil(controller.view.window)
        if bindValidationView { context.validating?.view = controller }
        prepareSolanaFormValues(context)
        return NativeSolanaForm(context: context, window: window, root: root, navigation: navigation, controller: controller)
    }

    private struct NativeSolanaForm {
        let context: PresenterContext
        let window: UIWindow
        let root: UIViewController
        let navigation: UINavigationController
        let controller: SendViewController
    }
}


extension SendDependencyErrorSurfacingTests {
    @MainActor
    func testSolanaFormNativeActualProceedButtonOpensConfirmation() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let (_, model) = try await presentActualFormWarning(native)
        try XCTUnwrap(model.actions.first).button.sendActions(for: .touchUpInside)
        try await waitForFormUI { native.controller.presentedViewController == nil }
        XCTAssertEqual(native.context.router.confirmations.count, 1)
    }

    @MainActor
    func testSolanaFormNativeActualProceedWithoutAnimationsOpensConfirmation() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let (_, model) = try await presentActualFormWarning(native)
        let animations = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animations) }
        try XCTUnwrap(model.actions.first).button.sendActions(for: .touchUpInside)
        try await waitForFormUI { native.controller.presentedViewController == nil }
        XCTAssertEqual(native.context.router.confirmations.count, 1)
    }

    @MainActor
    func testSolanaFormNativeActualCancelRejectsOldProceedAndAllowsFreshContinue() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let (sheet, model) = try await presentActualFormWarning(native)
        let proceed = try XCTUnwrap(model.actions.first?.handler)
        sheet.rootView.closeButton.sendActions(for: .touchUpInside)
        try await waitForFormUI { native.controller.presentedViewController == nil }
        proceed()
        let obsoleteRoutes = native.context.router.confirmations.count
        native.context.interactor.validationOverride = .valid(Self.formRecipient)
        native.context.presenter.didTapContinueButton()
        XCTAssertEqual(native.context.router.confirmations.count, obsoleteRoutes + 1)
        XCTAssertEqual(obsoleteRoutes, 0)
    }

    @MainActor
    func testSolanaFormNativeBackgroundOwnedWarningThenCancelAllowsFreshContinue() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let (sheet, model) = try await presentActualFormWarning(native)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        sheet.rootView.closeButton.sendActions(for: .touchUpInside)
        try await waitForFormUI { native.controller.presentedViewController == nil }
        try XCTUnwrap(model.actions.first?.handler)()
        XCTAssertTrue(native.context.router.confirmations.isEmpty)
        native.context.interactor.validationOverride = .valid(Self.formRecipient)
        native.context.presenter.didTapContinueButton()
        XCTAssertEqual(native.context.router.confirmations.count, 1)
    }

    @MainActor
    func testSolanaFormNativeCustomCoverRejectsOldWarningAndRecovers() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let proceed = try retainedFormProceed(native.context)
        let cover = UIViewController()
        cover.modalPresentationStyle = .custom
        await withCheckedContinuation { continuation in
            native.controller.present(cover, animated: false) { continuation.resume() }
        }
        XCTAssertTrue(native.controller.presentedViewController === cover)
        XCTAssertNotNil(cover.view.window)
        proceed()
        let coveredRoutes = native.context.router.confirmations.count
        await withCheckedContinuation { continuation in cover.dismiss(animated: false) { continuation.resume() } }
        native.context.interactor.validationOverride = .valid(Self.formRecipient)
        native.context.presenter.didTapContinueButton()
        XCTAssertEqual(native.context.router.confirmations.count, coveredRoutes + 1)
        XCTAssertEqual(coveredRoutes, 0)
    }

    @MainActor
    func testSolanaFormNativeCustomCoverRejectsNewContinueAndRecovers() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let cover = UIViewController()
        cover.modalPresentationStyle = .custom
        await withCheckedContinuation { continuation in
            native.controller.present(cover, animated: false) { continuation.resume() }
        }
        XCTAssertNotNil(cover.view.window)
        native.context.presenter.didTapContinueButton()
        let coveredRoutes = native.context.router.confirmations.count
        await withCheckedContinuation { continuation in cover.dismiss(animated: false) { continuation.resume() } }
        native.context.presenter.didTapContinueButton()
        XCTAssertEqual(native.context.router.confirmations.count, coveredRoutes + 1)
        XCTAssertEqual(coveredRoutes, 0)
    }

    @MainActor
    private func presentActualFormWarning(_ native: NativeSolanaForm) async throws -> (SheetAletViewController, SheetAlertPresentableViewModel) {
        native.context.router.formWarningForwarder = { model, view in
            SendRouter().presentFormWarning(viewModel: model, from: view)
        }
        _ = try retainedFormProceed(native.context)
        try await waitForFormUI {
            guard let sheet = native.controller.presentedViewController else { return false }
            return sheet.viewIfLoaded?.window != nil && !sheet.isBeingPresented
        }
        let sheet = try XCTUnwrap(native.controller.presentedViewController as? SheetAletViewController)
        let model = try XCTUnwrap(native.context.router.presentedSheets.last)
        return (sheet, model)
    }

    @MainActor
    private func waitForFormUI(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !condition(), Date() < deadline { try await Task.sleep(nanoseconds: 20_000_000) }
        XCTAssertTrue(condition(), "Native form transition did not finish within five seconds")
    }
}

extension SendDependencyErrorSurfacingTests {
    @MainActor
    func testSolanaFormNativeCustomCoverReturnCannotReviveUntouchedWarning() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let proceed = try retainedFormProceed(native.context)
        let cover = UIViewController()
        cover.modalPresentationStyle = .custom
        await withCheckedContinuation { continuation in
            native.controller.present(cover, animated: false) { continuation.resume() }
        }
        XCTAssertTrue(native.controller.presentedViewController === cover)
        XCTAssertNotNil(cover.view.window)
        await withCheckedContinuation { continuation in cover.dismiss(animated: false) { continuation.resume() } }
        XCTAssertNil(native.controller.presentedViewController)
        // No old callback or fresh action ran while covered: presentation itself must revoke it.
        proceed()
        let obsoleteRoutes = native.context.router.confirmations.count
        native.context.interactor.validationOverride = .valid(Self.formRecipient)
        native.context.presenter.didTapContinueButton()
        XCTAssertEqual(native.context.router.confirmations.count, obsoleteRoutes + 1)
        XCTAssertEqual(obsoleteRoutes, 0)
    }

    @MainActor
    func testSolanaFormConfirmationCarriesOriginalSelectionLease() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection)
        context.presenter.didTapContinueButton()
        XCTAssertEqual(context.router.confirmations.count, 1)
        let lease = try XCTUnwrap(context.router.confirmations.first?.selection)
        XCTAssertTrue(lease.isCurrent)
        try await saveSolanaSelection(selection.other, settings: selection.settings)
        try await saveSolanaSelection(selection.original, settings: selection.settings)
        XCTAssertFalse(lease.isCurrent, "Returning to the same wallet must not renew the originating form lease")
    }

    @MainActor
    func testSolanaFormConfirmationFactoryRejectsOriginatingLeaseAfterAtoBtoA() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection)
        context.presenter.didTapContinueButton()
        let route = try XCTUnwrap(context.router.confirmations.first)
        let lease = try XCTUnwrap(route.selection)
        try await saveSolanaSelection(selection.other, settings: selection.settings)
        try await saveSolanaSelection(selection.original, settings: selection.settings)
        XCTAssertFalse(lease.isCurrent)
        let view = WalletSendConfirmViewFactory.createView(wallet: route.wallet, chainAsset: route.asset,
            call: route.call, scamInfo: nil, feeViewModel: nil, selection: lease)
        XCTAssertNil(view)
    }

    @MainActor
    func testSolanaFormConfirmationFactoryAcceptsCurrentOriginatingLease() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection)
        context.presenter.didTapContinueButton()
        let route = try XCTUnwrap(context.router.confirmations.first)
        let lease = try XCTUnwrap(route.selection)
        XCTAssertTrue(lease.isCurrent)
        // Construct only: loading the production view would start public balance subscriptions.
        let view = WalletSendConfirmViewFactory.createView(wallet: route.wallet, chainAsset: route.asset,
            call: route.call, scamInfo: nil, feeViewModel: nil, selection: lease)
        XCTAssertNotNil(view)
        XCTAssertNil(view?.controller.viewIfLoaded)
    }

    @MainActor
    func testSolanaFormOriginatingLeaseRejectsFreshPipelineAfterAtoBtoA() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let form = makeSolanaForm(selection: selection)
        form.presenter.didTapContinueButton()
        let lease = try XCTUnwrap(form.router.confirmations.first?.selection)
        try await saveSolanaSelection(selection.other, settings: selection.settings)
        try await saveSolanaSelection(selection.original, settings: selection.settings)
        let pipeline = try makeSolanaPipeline(hold: .none, selectedWallet: selection.original,
            selectionSettings: selection.settings, originatingSelection: lease)
        pipeline.interactor.submitExtrinsic()
        XCTAssertNil(pipeline.interactor.transferTask)
        XCTAssertEqual(pipeline.keys.reads, 0)
        XCTAssertTrue(pipeline.transport.sent.isEmpty)
        XCTAssertNil(pipeline.store.pending(for: pipeline.scope))
        XCTAssertTrue(pipeline.wireframe.completedHashes.isEmpty)
    }

    @MainActor
    func testSolanaFormCurrentOriginatingLeaseAllowsIsolatedPipeline() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let form = makeSolanaForm(selection: selection)
        form.presenter.didTapContinueButton()
        let lease = try XCTUnwrap(form.router.confirmations.first?.selection)
        let pipeline = try makeSolanaPipeline(hold: .none, selectedWallet: selection.original,
            selectionSettings: selection.settings, originatingSelection: lease)
        pipeline.interactor.submitExtrinsic()
        try await XCTUnwrap(pipeline.interactor.transferTask).value
        let record = try XCTUnwrap(pipeline.store.pending(for: pipeline.scope))
        XCTAssertEqual(pipeline.keys.reads, 1)
        XCTAssertEqual(pipeline.transport.sent, [record.transactionBase64])
        XCTAssertTrue(record.reportedAsSent)
        XCTAssertEqual(pipeline.wireframe.completedHashes, [record.signature])
    }
}


extension SendViewStub: Localizable {
    func applyLocalization() {}
}

extension SendDependencyErrorSurfacingTests {
    @MainActor
    func testSolanaAmountWarningCurrentProceedRemainsUsable() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection, bindValidationView: true)
        let proceed = try retainedSolanaAmountWarning(context, action: 0)
        proceed()
        XCTAssertEqual(context.view.sendAllStates.last, true)
    }

    @MainActor
    func testSolanaAmountWarningCurrentMaxUsesExactBalanceMinusFee() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection, bindValidationView: true)
        let setMax = try retainedSolanaAmountWarning(context, action: 1)
        setMax()
        context.presenter.didTapContinueButton()
        XCTAssertEqual(context.router.confirmations.count, 1)
        XCTAssertEqual(context.router.confirmations.first?.call.amount, BigUInt(9_999_995_000))
    }

    @MainActor
    func testSolanaAmountWarningOldMaxCannotReplaceFreshAmount() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection, bindValidationView: true)
        let setMax = try retainedSolanaAmountWarning(context, action: 1)
        context.presenter.updateAmount(0.02)
        setMax()
        context.presenter.didTapContinueButton()
        XCTAssertEqual(context.router.confirmations.count, 1)
        XCTAssertEqual(context.router.confirmations.first?.call.amount, BigUInt(20_000_000))
    }

    @MainActor
    func testSolanaAmountWarningOldCancelCannotClearFreshAmount() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection, bindValidationView: true)
        let cancel = try retainedSolanaAmountWarning(context, action: 2)
        context.presenter.updateAmount(0.02)
        cancel()
        context.presenter.didTapContinueButton()
        XCTAssertEqual(context.router.confirmations.count, 1)
        XCTAssertEqual(context.router.confirmations.first?.call.amount, BigUInt(20_000_000))
    }

    @MainActor
    func testSolanaAmountWarningOldProceedCannotEnableSendAllAfterEdit() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection, bindValidationView: true)
        let proceed = try retainedSolanaAmountWarning(context, action: 0)
        context.presenter.updateAmount(0.02)
        let states = context.view.sendAllStates
        proceed()
        XCTAssertEqual(context.view.sendAllStates, states)
        context.presenter.didTapContinueButton()
        XCTAssertEqual(context.router.confirmations.first?.call.amount, BigUInt(20_000_000))
    }

    @MainActor
    func testSolanaAmountWarningOldMaxCannotMutateReselectedForm() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection, bindValidationView: true)
        let setMax = try retainedSolanaAmountWarning(context, action: 1)
        try await saveSolanaSelection(selection.other, settings: selection.settings)
        try await saveSolanaSelection(selection.original, settings: selection.settings)
        let states = context.view.sendAllStates
        let inputs = context.view.amountInputs.count
        setMax()
        XCTAssertEqual(context.view.sendAllStates, states)
        XCTAssertEqual(context.view.amountInputs.count, inputs)
        let fresh = makeSolanaForm(selection: selection, bindValidationView: true)
        fresh.presenter.didTapContinueButton()
        XCTAssertEqual(fresh.router.confirmations.count, 1)
    }

    @MainActor
    func testSolanaAmountWarningOldMaxCannotMutateAfterBack() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection, bindValidationView: true)
        let setMax = try retainedSolanaAmountWarning(context, action: 1)
        context.presenter.didTapBackButton()
        let states = context.view.sendAllStates
        let inputs = context.view.amountInputs.count
        setMax()
        XCTAssertEqual(context.view.sendAllStates, states)
        XCTAssertEqual(context.view.amountInputs.count, inputs)
    }

    @MainActor
    func testSolanaAmountWarningOldMaxCannotAdoptChangedBalance() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection, bindValidationView: true)
        let setMax = try retainedSolanaAmountWarning(context, action: 1)
        context.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: BigUInt(1_000_000_000))), for: context.chainAsset)
        context.presenter.updateAmount(0.02)
        setMax()
        context.presenter.didTapContinueButton()
        XCTAssertEqual(context.router.confirmations.first?.call.amount, BigUInt(20_000_000))
    }

    @MainActor
    func testSolanaAmountWarningMaxActionIsConsumedOnce() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let context = makeSolanaForm(selection: selection, bindValidationView: true)
        let setMax = try retainedSolanaAmountWarning(context, action: 1)
        setMax()
        let states = context.view.sendAllStates
        let inputs = context.view.amountInputs.count
        setMax()
        XCTAssertEqual(context.view.sendAllStates, states)
        XCTAssertEqual(context.view.amountInputs.count, inputs)
        context.presenter.didTapContinueButton()
        XCTAssertEqual(context.router.confirmations.first?.call.amount, BigUInt(9_999_995_000))
    }

    @MainActor
    func testSolanaFormNativeInactiveReturnRevokesUntouchedWarning() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let proceed = try retainedFormProceed(native.context)
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        proceed()
        let obsoleteRoutes = native.context.router.confirmations.count
        native.context.interactor.validationOverride = .valid(Self.formRecipient)
        native.context.presenter.didTapContinueButton()
        XCTAssertEqual(native.context.router.confirmations.count, obsoleteRoutes + 1)
        XCTAssertEqual(obsoleteRoutes, 0)
    }

    @MainActor
    func testSolanaFormNativeInactiveRejectsNewContinueUntilActive() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        native.context.presenter.didTapContinueButton()
        let inactiveRoutes = native.context.router.confirmations.count
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        native.context.presenter.didTapContinueButton()
        XCTAssertEqual(native.context.router.confirmations.count, inactiveRoutes + 1)
        XCTAssertEqual(inactiveRoutes, 0)
    }

    @MainActor
    private func retainedSolanaAmountWarning(_ context: PresenterContext, action: Int) throws -> () -> Void {
        context.presenter.updateAmount(11)
        let model = try XCTUnwrap(context.router.presentedSheets.last)
        XCTAssertEqual(model.actions.count, 3)
        return try XCTUnwrap(model.actions[action].handler)
    }
}

extension SendDependencyErrorSurfacingTests {
    @MainActor
    func testSolanaFormNativeSceneInactiveReturnRevokesUntouchedWarning() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let scene = try XCTUnwrap(native.window.windowScene)
        let proceed = try retainedFormProceed(native.context)
        NotificationCenter.default.post(name: UIScene.willDeactivateNotification, object: scene)
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: scene)
        proceed()
        let obsoleteRoutes = native.context.router.confirmations.count
        native.context.interactor.validationOverride = .valid(Self.formRecipient)
        native.context.presenter.didTapContinueButton()
        XCTAssertEqual(native.context.router.confirmations.count, obsoleteRoutes + 1)
        XCTAssertEqual(obsoleteRoutes, 0)
    }

    @MainActor
    func testSolanaFormNativeSceneInactiveRejectsNewContinueUntilActive() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let scene = try XCTUnwrap(native.window.windowScene)
        NotificationCenter.default.post(name: UIScene.willDeactivateNotification, object: scene)
        native.context.presenter.didTapContinueButton()
        let inactiveRoutes = native.context.router.confirmations.count
        NotificationCenter.default.post(name: UIScene.didActivateNotification, object: scene)
        native.context.presenter.didTapContinueButton()
        XCTAssertEqual(native.context.router.confirmations.count, inactiveRoutes + 1)
        XCTAssertEqual(inactiveRoutes, 0)
    }

    @MainActor
    func testSolanaFormNativeUnrelatedSceneNotificationKeepsWarningUsable() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let proceed = try retainedFormProceed(native.context)
        NotificationCenter.default.post(name: UIScene.willDeactivateNotification, object: NSObject())
        proceed()
        XCTAssertEqual(native.context.router.confirmations.count, 1)
    }
}

extension SendDependencyErrorSurfacingTests {
    @MainActor
    func testSolanaAmountNativeActualMaxPreservesExactAmount() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection, bindValidationView: true)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let (_, model) = try await presentActualAmountWarning(native)
        model.actions[1].button.sendActions(for: .touchUpInside)
        try await waitForFormUI { native.controller.presentedViewController == nil }
        native.context.presenter.didTapContinueButton()
        XCTAssertEqual(native.context.router.confirmations.count, 1)
        XCTAssertEqual(native.context.router.confirmations.first?.call.amount, BigUInt(9_999_995_000))
    }

    @MainActor
    func testSolanaAmountNativeActualProceedPreservesEnteredAmount() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection, bindValidationView: true)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let (_, model) = try await presentActualAmountWarning(native)
        model.actions[0].button.sendActions(for: .touchUpInside)
        try await waitForFormUI { native.controller.presentedViewController == nil }
        native.context.presenter.didTapContinueButton()
        XCTAssertEqual(native.context.router.confirmations.count, 1)
        XCTAssertEqual(native.context.router.confirmations.first?.call.amount, BigUInt(9_500_000_000))
    }

    @MainActor
    func testSolanaAmountNativeActualCancelAllowsFreshAmount() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection, bindValidationView: true)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let (_, model) = try await presentActualAmountWarning(native)
        model.actions[2].button.sendActions(for: .touchUpInside)
        try await waitForFormUI { native.controller.presentedViewController == nil }
        native.context.presenter.updateAmount(0.02)
        native.context.presenter.didTapContinueButton()
        XCTAssertEqual(native.context.router.confirmations.count, 1)
        XCTAssertEqual(native.context.router.confirmations.first?.call.amount, BigUInt(20_000_000))
    }

    @MainActor
    func testSolanaAmountNativeExternalDismissalCannotRetainMaxAction() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection, bindValidationView: true)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let (sheet, model) = try await presentActualAmountWarning(native)
        let oldMax = try XCTUnwrap(model.actions[1].handler)
        await withCheckedContinuation { continuation in sheet.dismiss(animated: false) { continuation.resume() } }
        XCTAssertNil(native.controller.presentedViewController)
        native.context.presenter.updateAmount(0.02)
        oldMax()
        native.context.presenter.didTapContinueButton()
        XCTAssertEqual(native.context.router.confirmations.count, 1)
        XCTAssertEqual(native.context.router.confirmations.first?.call.amount, BigUInt(20_000_000))
    }

    @MainActor
    private func presentActualAmountWarning(_ native: NativeSolanaForm, validationOnContinue: Bool = false) async throws -> (SheetAletViewController, SheetAlertPresentableViewModel) {
        native.context.router.sheetForwarder = { model, view in
            SendRouter().present(viewModel: model, from: view)
        }
        native.context.router.formWarningForwarder = { model, view in
            SendRouter().presentFormWarning(viewModel: model, from: view)
        }
        if validationOnContinue {
            native.context.presenter.updateAmount(9.5)
            native.context.presenter.didReceiveMinimumBalance(result: .success(BigUInt(1_000_000_000)))
            native.context.presenter.didTapContinueButton()
        } else {
            native.context.presenter.didReceiveMinimumBalance(result: .success(BigUInt(1_000_000_000)))
            native.context.presenter.updateAmount(9.5)
        }
        try await waitForFormUI {
            guard let sheet = native.controller.presentedViewController else { return false }
            return sheet.viewIfLoaded?.window != nil && !sheet.isBeingPresented
        }
        let sheet = try XCTUnwrap(native.controller.presentedViewController as? SheetAletViewController)
        let model = try XCTUnwrap(native.context.router.presentedSheets.last)
        XCTAssertEqual(model.actions.count, 3)
        return (sheet, model)
    }
}

extension SendDependencyErrorSurfacingTests {
    @MainActor
    func testSolanaFullValidationNativeActualMaxPreservesExactAmount() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection, bindValidationView: true)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let (_, model) = try await presentActualAmountWarning(native, validationOnContinue: true)
        model.actions[1].button.sendActions(for: .touchUpInside)
        try await waitForFormUI { native.controller.presentedViewController == nil }
        native.context.presenter.didTapContinueButton()
        XCTAssertEqual(native.context.router.confirmations.count, 1)
        XCTAssertEqual(native.context.router.confirmations.first?.call.amount, BigUInt(9_999_995_000))
    }

    @MainActor
    func testSolanaFullValidationNativeActualProceedPreservesEnteredAmount() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection, bindValidationView: true)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let (_, model) = try await presentActualAmountWarning(native, validationOnContinue: true)
        model.actions[0].button.sendActions(for: .touchUpInside)
        try await waitForFormUI { native.controller.presentedViewController == nil }
        native.context.presenter.didTapContinueButton()
        XCTAssertEqual(native.context.router.confirmations.count, 1)
        XCTAssertEqual(native.context.router.confirmations.first?.call.amount, BigUInt(9_500_000_000))
    }

    @MainActor
    func testSolanaFullValidationNativeActualCancelAllowsFreshAmount() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let native = try makeNativeSolanaForm(selection: selection, bindValidationView: true)
        defer { native.window.isHidden = true; native.window.rootViewController = nil }
        let (_, model) = try await presentActualAmountWarning(native, validationOnContinue: true)
        model.actions[2].button.sendActions(for: .touchUpInside)
        try await waitForFormUI { native.controller.presentedViewController == nil }
        native.context.presenter.updateAmount(0.02)
        native.context.presenter.didTapContinueButton()
        XCTAssertEqual(native.context.router.confirmations.count, 1)
        XCTAssertEqual(native.context.router.confirmations.first?.call.amount, BigUInt(20_000_000))
    }

}


extension SendDependencyErrorSurfacingTests {
    @MainActor
    func testSolanaNativeInputCurrentContinueUsesVisibleAmount() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let (native, _) = try await makeNativeAmountInput(selection: selection)
        defer { closeNativeAmountInput(native) }
        native.controller.rootView.actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(native.context.router.confirmations.count, 1)
        XCTAssertEqual(native.context.router.confirmations.first?.call.amount, BigUInt(20_000_000))
    }

    @MainActor
    func testSolanaNativeInputImmediateContinueUsesEditedAmount() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let (native, _) = try await makeNativeAmountInput(selection: selection)
        defer { closeNativeAmountInput(native) }
        replaceNativeAmountInput(native, with: "0.03")
        XCTAssertEqual(native.controller.rootView.amountView.textField.text, "0.03")
        native.controller.rootView.actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(native.context.router.confirmations.count, 1)
        XCTAssertEqual(native.context.router.confirmations.first?.call.amount, BigUInt(30_000_000))
    }

    @MainActor
    func testSolanaNativeInputImmediateContinueCannotUseClearedAmount() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let (native, _) = try await makeNativeAmountInput(selection: selection)
        defer { closeNativeAmountInput(native) }
        replaceNativeAmountInput(native, with: "")
        native.controller.rootView.actionButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(native.context.router.confirmations.isEmpty)
    }

    @MainActor
    func testSolanaNativeInputQueuedPercentageCannotOverwriteLaterEdit() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let (native, _) = try await makeNativeAmountInput(selection: selection)
        defer { closeNativeAmountInput(native) }
        native.context.presenter.selectAmountPercentage(0.5)
        replaceNativeAmountInput(native, with: "0.03")
        await drainNativeAmountQueue()
        XCTAssertEqual(native.controller.rootView.amountView.textField.text, "0.03")
        native.context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 5_000)))
        native.controller.rootView.actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(native.context.router.confirmations.first?.call.amount, BigUInt(30_000_000))
    }

    @MainActor
    func testSolanaNativeInputPendingEditDoesNotRequestFeeAfterBack() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let (native, _) = try await makeNativeAmountInput(selection: selection)
        defer { closeNativeAmountInput(native) }
        replaceNativeAmountInput(native, with: "0.03")
        native.controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)
        let estimates = native.context.interactor.estimatedAmounts
        try await Task.sleep(nanoseconds: 900_000_000)
        XCTAssertEqual(native.context.interactor.estimatedAmounts, estimates)
        XCTAssertEqual(native.context.router.dismissCount, 1)
    }

    @MainActor
    func testSolanaNativeInputReplacedModelCannotTriggerCurrentAmountWork() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let (native, oldModel) = try await makeNativeAmountInput(selection: selection)
        defer { closeNativeAmountInput(native) }
        let current = nativeAmountModel(selection: selection, amount: 0.04)
        native.controller.didReceive(amountInputViewModel: current)
        native.context.presenter.updateAmount(0.04)
        await drainNativeAmountQueue()
        let estimates = native.context.interactor.estimatedAmounts
        oldModel.didUpdateAmount(to: 0.07)
        try await Task.sleep(nanoseconds: 900_000_000)
        XCTAssertEqual(native.context.interactor.estimatedAmounts, estimates)
        XCTAssertEqual(native.controller.rootView.amountView.textField.text, "0.04")
    }

    @MainActor
    func testSolanaNativeInputSettledEditStillUsesCurrentAmount() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let (native, _) = try await makeNativeAmountInput(selection: selection)
        defer { closeNativeAmountInput(native) }
        replaceNativeAmountInput(native, with: "0.03")
        try await Task.sleep(nanoseconds: 900_000_000)
        native.context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 5_000)))
        native.controller.rootView.actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(native.context.router.confirmations.count, 1)
        XCTAssertEqual(native.context.router.confirmations.first?.call.amount, BigUInt(30_000_000))
    }

    @MainActor
    func testSolanaNativeInputCurrentPercentageStillUpdatesVisibleAmount() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let (native, _) = try await makeNativeAmountInput(selection: selection)
        defer { closeNativeAmountInput(native) }
        native.context.presenter.selectAmountPercentage(0.5)
        await drainNativeAmountQueue()
        native.context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 5_000)))
        native.controller.rootView.actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(native.context.router.confirmations.count, 1)
        XCTAssertEqual(native.context.router.confirmations.first?.call.amount, BigUInt(4_999_997_500))
        XCTAssertNotEqual(native.controller.rootView.amountView.textField.text, "0.02")
    }

    @MainActor
    private func nativeAmountModel(selection: SolanaSelectionFixture, amount: Decimal) -> IAmountInputViewModel {
        BalanceViewModelFactory(targetAssetInfo: Self.solAsset.displayInfo(with: Self.solanaChain.icon),
            selectedMetaAccount: selection.original).createBalanceInputViewModel(amount).value(for: Locale(identifier: "en_US"))
    }

    @MainActor
    private func makeNativeAmountInput(selection: SolanaSelectionFixture) async throws -> (NativeSolanaForm, IAmountInputViewModel) {
        let native = try makeNativeSolanaForm(selection: selection, bindValidationView: true)
        await drainNativeAmountQueue()
        let model = nativeAmountModel(selection: selection, amount: 0.02)
        native.controller.didReceive(amountInputViewModel: model)
        native.controller.didStopFeeCalculation()
        XCTAssertEqual(native.controller.rootView.amountView.textField.text, "0.02")
        return (native, model)
    }

    @MainActor
    private func replaceNativeAmountInput(_ native: NativeSolanaForm, with text: String) {
        let field = native.controller.rootView.amountView.textField
        _ = native.controller.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: (field.text ?? "").utf16.count), replacementString: text)
    }

    @MainActor
    private func drainNativeAmountQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    @MainActor
    private func closeNativeAmountInput(_ native: NativeSolanaForm) {
        NSObject.cancelPreviousPerformRequests(withTarget: native.controller)
        native.window.isHidden = true
        native.window.rootViewController = nil
    }
}


extension SendDependencyErrorSurfacingTests {
    @MainActor
    func testSolanaNativeInputInactiveReturnCannotRevivePendingFeeWork() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let (native, _) = try await makeNativeAmountInput(selection: selection)
        defer { closeNativeAmountInput(native) }
        replaceNativeAmountInput(native, with: "0.03")
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        let estimates = native.context.interactor.estimatedAmounts
        try await Task.sleep(nanoseconds: 900_000_000)
        XCTAssertEqual(native.context.interactor.estimatedAmounts, estimates)
        replaceNativeAmountInput(native, with: "0.04")
        try await Task.sleep(nanoseconds: 900_000_000)
        XCTAssertEqual(native.context.interactor.estimatedAmounts.last, BigUInt(40_000_000))
        XCTAssertEqual(native.context.interactor.estimatedAmounts.count, estimates.count + 1)
    }

    @MainActor
    func testSolanaNativeInputWalletRoundTripCannotRevivePendingFeeWork() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let (native, _) = try await makeNativeAmountInput(selection: selection)
        defer { closeNativeAmountInput(native) }
        replaceNativeAmountInput(native, with: "0.03")
        let estimates = native.context.interactor.estimatedAmounts
        try await saveSolanaSelection(selection.other, settings: selection.settings)
        try await saveSolanaSelection(selection.original, settings: selection.settings)
        try await Task.sleep(nanoseconds: 900_000_000)
        XCTAssertEqual(native.context.interactor.estimatedAmounts, estimates)
        let fresh = makeSolanaForm(selection: selection)
        fresh.presenter.didTapContinueButton()
        XCTAssertEqual(fresh.router.confirmations.count, 1)
    }

    @MainActor
    func testSolanaNativeInputNavigationReturnKeepsPendingFeeRevokedAndFreshEditUsable() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let (native, _) = try await makeNativeAmountInput(selection: selection)
        defer { closeNativeAmountInput(native) }
        replaceNativeAmountInput(native, with: "0.03")
        native.navigation.pushViewController(UIViewController(), animated: false)
        native.window.layoutIfNeeded()
        XCTAssertNil(native.controller.view.window)
        native.navigation.popViewController(animated: false)
        native.window.layoutIfNeeded()
        XCTAssertNotNil(native.controller.view.window)
        let estimates = native.context.interactor.estimatedAmounts
        try await Task.sleep(nanoseconds: 900_000_000)
        XCTAssertEqual(native.context.interactor.estimatedAmounts, estimates)
        replaceNativeAmountInput(native, with: "0.04")
        try await Task.sleep(nanoseconds: 900_000_000)
        XCTAssertEqual(native.context.interactor.estimatedAmounts.last, BigUInt(40_000_000))
        XCTAssertEqual(native.context.interactor.estimatedAmounts.count, estimates.count + 1)
    }
}


extension SendDependencyErrorSurfacingTests {
    @MainActor
    func testSolanaNativeInputCurrentPendingEditSurvivesFeeAndBalanceUpdates() async throws {
        let selection = try await makeSolanaSelectionFixture()
        let (native, _) = try await makeNativeAmountInput(selection: selection)
        defer { closeNativeAmountInput(native) }
        replaceNativeAmountInput(native, with: "0.03")
        let estimates = native.context.interactor.estimatedAmounts
        native.context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 6_000)))
        native.context.presenter.didReceiveAccountInfo(result: .success(AccountInfo(ethBalance: BigUInt(9_000_000_000))),
            for: native.context.chainAsset)
        try await Task.sleep(nanoseconds: 900_000_000)
        XCTAssertEqual(native.context.interactor.estimatedAmounts, estimates + [BigUInt(30_000_000)])
        native.context.presenter.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 6_000)))
        native.controller.rootView.actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(native.context.router.confirmations.count, 1)
        XCTAssertEqual(native.context.router.confirmations.first?.call.amount, BigUInt(30_000_000))
    }
}

// Actual native recipient controls with an input-sensitive lower validator for two public fixtures.
// Queued contact/clear ordering is deliberately controlled; no physical event-timing claim.
extension SendDependencyErrorSurfacingTests {
    private static let otherFormRecipient = "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk"

    @MainActor
    func testSolanaNativeRecipientCurrentContinueMatchesRenderedRecipient() async throws {
        let native = try await makeNativeRecipientInput()
        defer { closeNativeAmountInput(native) }
        XCTAssertEqual(native.controller.rootView.searchView.textField.text, Self.formRecipient)
        native.controller.rootView.actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(native.context.router.confirmations.count, 1)
        XCTAssertEqual(native.context.router.confirmations.first?.call.receiverAddress, Self.formRecipient)
    }

    @MainActor
    func testSolanaNativeRecipientClearDisablesContinueAndCannotConfirm() async throws {
        let native = try await makeNativeRecipientInput()
        defer { closeNativeAmountInput(native) }
        try nativeRecipientButton("clean", in: native.controller.rootView.searchView).sendActions(for: .touchUpInside)
        XCTAssertTrue(native.controller.rootView.searchView.textField.text?.isEmpty != false)
        XCTAssertFalse(native.controller.rootView.actionButton.isEnabled)
        native.controller.rootView.actionButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(native.context.router.confirmations.isEmpty)
    }

    @MainActor
    func testSolanaNativeRecipientDisplayRejectsKeyboardEditingAndKeepsCurrentRecipient() async throws {
        let native = try await makeNativeRecipientInput()
        defer { closeNativeAmountInput(native) }
        let field = native.controller.rootView.searchView.textField
        XCTAssertTrue(field.becomeFirstResponder())
        // This display redirects editing to contacts/paste; didBeginEditing resigns immediately.
        XCTAssertFalse(field.isFirstResponder)
        XCTAssertEqual(field.text, Self.formRecipient)
        XCTAssertTrue(native.controller.rootView.actionButton.isEnabled)
        native.controller.rootView.actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(native.context.router.confirmations.count, 1)
        XCTAssertEqual(native.context.router.confirmations.first?.call.receiverAddress, Self.formRecipient)
    }

    @MainActor
    func testSolanaNativeRecipientSettledContactShowsAndConfirmsSameAddress() async throws {
        let native = try await makeNativeRecipientInput()
        defer { closeNativeAmountInput(native) }
        native.context.presenter.didSelect(address: Self.otherFormRecipient)
        await drainNativeAmountQueue()
        XCTAssertEqual(native.controller.rootView.searchView.textField.text, Self.otherFormRecipient)
        native.controller.rootView.actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(native.context.router.confirmations.count, 1)
        XCTAssertEqual(native.context.router.confirmations.first?.call.receiverAddress, Self.otherFormRecipient)
    }

    @MainActor
    func testSolanaNativeRecipientQueuedContactCannotRestoreClearedField() async throws {
        let native = try await makeNativeRecipientInput()
        defer { closeNativeAmountInput(native) }
        let clear = try nativeRecipientButton("clean", in: native.controller.rootView.searchView)
        XCTAssertFalse(clear.isHidden)
        native.context.presenter.didSelect(address: Self.otherFormRecipient)
        clear.sendActions(for: .touchUpInside)
        XCTAssertTrue(native.controller.rootView.searchView.textField.text?.isEmpty != false)
        await drainNativeAmountQueue()
        XCTAssertTrue(native.controller.rootView.searchView.textField.text?.isEmpty != false)
        native.controller.rootView.actionButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(native.context.router.confirmations.isEmpty)
    }

    @MainActor
    func testSolanaNativeRecipientFreshContactAfterClearRemainsUsable() async throws {
        let native = try await makeNativeRecipientInput()
        defer { closeNativeAmountInput(native) }
        try nativeRecipientButton("clean", in: native.controller.rootView.searchView).sendActions(for: .touchUpInside)
        await drainNativeAmountQueue()
        native.context.presenter.didSelect(address: Self.otherFormRecipient)
        await drainNativeAmountQueue()
        XCTAssertEqual(native.controller.rootView.searchView.textField.text, Self.otherFormRecipient)
        XCTAssertTrue(native.controller.rootView.actionButton.isEnabled)
        native.controller.rootView.actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(native.context.router.confirmations.count, 1)
        XCTAssertEqual(native.context.router.confirmations.first?.call.receiverAddress, Self.otherFormRecipient)
    }

    @MainActor
    func testSolanaNativeRecipientLaterContactWinsQueuedReplacement() async throws {
        let native = try await makeNativeRecipientInput()
        defer { closeNativeAmountInput(native) }
        native.context.presenter.didSelect(address: Self.otherFormRecipient)
        native.context.presenter.didSelect(address: Self.formRecipient)
        await drainNativeAmountQueue()
        XCTAssertEqual(native.controller.rootView.searchView.textField.text, Self.formRecipient)
        native.controller.rootView.actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(native.context.router.confirmations.count, 1)
        XCTAssertEqual(native.context.router.confirmations.first?.call.receiverAddress, Self.formRecipient)
    }

    @MainActor
    func testSolanaNativeRecipientFreshNativePasteAfterClearRemainsUsable() async throws {
        let previousPasteboard = UIPasteboard.general.items
        defer { UIPasteboard.general.items = previousPasteboard }
        let native = try await makeNativeRecipientInput()
        defer { closeNativeAmountInput(native) }
        try nativeRecipientButton("clean", in: native.controller.rootView.searchView).sendActions(for: .touchUpInside)
        await drainNativeAmountQueue()
        UIPasteboard.general.string = Self.otherFormRecipient
        let paste = try nativeRecipientButton("pasteTapped", in: native.controller.rootView.searchView)
        XCTAssertFalse(paste.isHidden)
        paste.sendActions(for: .touchUpInside)
        await drainNativeAmountQueue()
        XCTAssertEqual(native.controller.rootView.searchView.textField.text, Self.otherFormRecipient)
        XCTAssertTrue(native.controller.rootView.actionButton.isEnabled)
        native.controller.rootView.actionButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(native.context.router.confirmations.count, 1)
        XCTAssertEqual(native.context.router.confirmations.first?.call.receiverAddress, Self.otherFormRecipient)
    }

    @MainActor
    private func makeNativeRecipientInput() async throws -> NativeSolanaForm {
        let selection = try await makeSolanaSelectionFixture()
        let (native, _) = try await makeNativeAmountInput(selection: selection)
        native.context.interactor.validationOverride = nil
        native.context.interactor.validationForInput = { value in
            guard let value, [Self.formRecipient, Self.otherFormRecipient].contains(value) else { return .invalid(value) }
            return .valid(value)
        }
        XCTAssertTrue(native.controller.rootView.actionButton.isEnabled)
        XCTAssertEqual(native.controller.rootView.searchView.textField.text, Self.formRecipient)
        return native
    }

    @MainActor
    private func nativeRecipientButton(_ action: String, in root: UIView) throws -> UIControl {
        var views = [root]
        while let view = views.popLast() {
            if let control = view as? UIControl,
               control.allTargets.contains(where: { control.actions(forTarget: $0.base, forControlEvent: .touchUpInside)?.contains(action) == true }) {
                return control
            }
            views.append(contentsOf: view.subviews)
        }
        throw NSError(domain: "native-recipient-button-not-found", code: 1, userInfo: ["action": action])
    }
}

import SoraKeystore

// Baseline: actual Send presenter/interactor/factory/controller; controlled lower lookups.
// No hosted window, live service, confirmation, signing, or physical-tap claim.
extension SendDependencyErrorSurfacingTests {
    @MainActor
    func testSendScamWarningCurrentRecipientResponseRemainsVisible() async throws {
        let fixture = try makeScamWarningOwnershipFixture()
        defer { fixture.close() }
        fixture.presenter.didSelect(address: fixture.second.address)
        await fulfillment(of: [fixture.second.started], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertEqual(fixture.controller.rootView.searchView.textField.text, fixture.second.address)
        XCTAssertEqual(fixture.second.observedChainId, fixture.chainAsset.chain.chainId)
        XCTAssertTrue(fixture.second.isHeld)
        XCTAssertTrue(fixture.controller.rootView.scamWarningView.isHidden)

        try fixture.second.release(warning: fixture.second.warning)
        await fulfillment(of: [fixture.second.returned], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertFalse(fixture.controller.rootView.scamWarningView.isHidden)
        XCTAssertTrue(scamWarningLabels(in: fixture.controller.rootView.scamWarningView).contains(fixture.second.warning.name))
        XCTAssertEqual(fixture.controller.rootView.searchView.textField.text, fixture.second.address)
    }

    @MainActor
    func testSendScamWarningDisplayedForOldRecipientRetiresWhileNewLookupIsHeld() async throws {
        let fixture = try makeScamWarningOwnershipFixture()
        defer { fixture.close() }
        fixture.presenter.didSelect(address: fixture.first.address)
        await fulfillment(of: [fixture.first.started], timeout: 2)
        try fixture.first.release(warning: fixture.first.warning)
        await fulfillment(of: [fixture.first.returned], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertFalse(fixture.controller.rootView.scamWarningView.isHidden)
        XCTAssertTrue(scamWarningLabels(in: fixture.controller.rootView.scamWarningView).contains(fixture.first.warning.name))
        XCTAssertEqual(fixture.controller.rootView.searchView.textField.text, fixture.first.address)

        fixture.presenter.didSelect(address: fixture.second.address)
        await fulfillment(of: [fixture.second.started], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertEqual(fixture.controller.rootView.searchView.textField.text, fixture.second.address)
        XCTAssertEqual(fixture.second.observedChainId, fixture.chainAsset.chain.chainId)
        XCTAssertTrue(fixture.second.isHeld, "The new recipient lookup has started but has not returned")
        XCTAssertTrue(
            fixture.controller.rootView.scamWarningView.isHidden,
            "A warning attributed to A must not remain beside the displayed recipient B"
        )

        try fixture.second.release(warning: fixture.second.warning)
        await fulfillment(of: [fixture.second.returned], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertFalse(fixture.controller.rootView.scamWarningView.isHidden)
        XCTAssertTrue(scamWarningLabels(in: fixture.controller.rootView.scamWarningView).contains(fixture.second.warning.name))
        XCTAssertEqual(fixture.controller.rootView.searchView.textField.text, fixture.second.address)
    }

    @MainActor
    func testSendScamWarningHeldOldResponseCannotRepopulateAfterActualClear() async throws {
        let fixture = try makeScamWarningOwnershipFixture()
        defer { fixture.close() }
        fixture.presenter.didSelect(address: fixture.first.address)
        await fulfillment(of: [fixture.first.started], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertEqual(fixture.controller.rootView.searchView.textField.text, fixture.first.address)
        XCTAssertTrue(fixture.first.isHeld)
        let clear = try nativeRecipientButton("clean", in: fixture.controller.rootView.searchView)
        XCTAssertFalse(clear.isHidden)
        clear.sendActions(for: .touchUpInside)
        await drainNativeAmountQueue()
        XCTAssertTrue(fixture.controller.rootView.searchView.textField.text?.isEmpty != false)
        XCTAssertTrue(fixture.controller.rootView.scamWarningView.isHidden)

        try fixture.first.release(warning: fixture.first.warning)
        await fulfillment(of: [fixture.first.returned], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertTrue(fixture.controller.rootView.searchView.textField.text?.isEmpty != false)
        XCTAssertTrue(
            fixture.controller.rootView.scamWarningView.isHidden,
            "The old request must not put its warning back after the actual Clear action"
        )

        fixture.presenter.didSelect(address: fixture.second.address)
        await fulfillment(of: [fixture.second.started], timeout: 2)
        try fixture.second.release(warning: fixture.second.warning)
        await fulfillment(of: [fixture.second.returned], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertFalse(fixture.controller.rootView.scamWarningView.isHidden)
        XCTAssertTrue(scamWarningLabels(in: fixture.controller.rootView.scamWarningView).contains(fixture.second.warning.name))
        XCTAssertEqual(fixture.controller.rootView.searchView.textField.text, fixture.second.address)
    }

    @MainActor
    private func makeScamWarningOwnershipFixture() throws -> SendScamWarningOwnershipFixture {
        let asset = try XCTUnwrap(SendNetworkFixture.assets().first { $0.chain.chainId == "1" && $0.isUtility })
        let wallet = AccountGenerator.generateMetaAccount()
        let container = SendDepencyContainer(wallet: wallet, operationManager: fearless.OperationManagerFacade.sharedManager)
        let first = SendScamWarningRequest(address: "0x1111111111111111111111111111111111111111", name: "Public warning A")
        let second = SendScamWarningRequest(address: "0x2222222222222222222222222222222222222222", name: "Public warning B")
        let warnings = SendScamWarningFetcher(requests: [first, second])
        let dependencies = SendScamWarningDependencyGate()
        let repository = ChainRepositoryFactory().createRepository(
            for: NSPredicate.enabledCHain(), sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let runtimeRepository: AsyncCoreDataRepositoryDefault<fearless.RuntimeMetadataItem, SSFAssetManagmentStorage.CDRuntimeMetadataItem> =
            SubstrateDataStorageFacade.shared.createAsyncRepository()
        let interactor = SendInteractor(
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared, selectedMetaAccount: wallet
            ),
            operationManager: fearless.OperationManagerFacade.sharedManager,
            scamInfoFetching: warnings,
            chainAssetFetching: ChainAssetsFetching(chainRepository: AnyDataProviderRepository(repository), operationQueue: OperationQueue()),
            dependencyContainer: container,
            addressChainDefiner: AddressChainDefiner(
                operationManager: fearless.OperationManagerFacade.sharedManager,
                chainModelRepository: AnyDataProviderRepository(repository), wallet: wallet
            ),
            runtimeItemRepository: AsyncAnyRepository(runtimeRepository),
            accountInfoRemoteService: AccountInfoRemoteServiceStub(),
            prepareDependencies: { _ in try await dependencies.wait() }
        )
        let router = SendRouterSpy()
        let settings = InMemorySettingsManager()
        settings.accountScoreEnabled = true
        let presenter = SendPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            viewModelFactory: SendViewModelFactory(
                iconGenerator: UniversalIconGenerator(), accountScoreFetcher: SendScamWarningScoreFetcher(), settings: settings
            ),
            dataValidatingFactory: SendDataValidatingFactory(presentable: router),
            wallet: wallet,
            initialData: .chainAsset(asset),
            tokenCatalog: CanonicalTokenGroupCatalog(data: nil, testnets: .bundled)
        )
        let controller = SendViewController(initialData: .chainAsset(asset), output: presenter, localizationManager: LocalizationManager.shared)
        controller.loadViewIfNeeded()
        return SendScamWarningOwnershipFixture(
            presenter: presenter, controller: controller, chainAsset: asset,
            first: first, second: second, warnings: warnings, dependencies: dependencies
        )
    }

    @MainActor
    private func scamWarningLabels(in root: UIView) -> [String] {
        var views = [root]
        var labels: [String] = []
        while let view = views.popLast() {
            if let label = view as? UILabel, let text = label.text { labels.append(text) }
            views.append(contentsOf: view.subviews)
        }
        return labels
    }
}

@MainActor
private struct SendScamWarningOwnershipFixture {
    let presenter: SendPresenter
    let controller: SendViewController
    let chainAsset: ChainAsset
    let first: SendScamWarningRequest
    let second: SendScamWarningRequest
    let warnings: SendScamWarningFetcher
    let dependencies: SendScamWarningDependencyGate

    func close() {
        warnings.close()
        dependencies.close()
    }
}

@MainActor
private final class SendScamWarningRequest {
    let address: String
    let warning: ScamInfo
    let started: XCTestExpectation
    let returned: XCTestExpectation
    var observedChainId: String?
    var continuation: CheckedContinuation<ScamInfo?, Never>?
    var isHeld: Bool { continuation != nil }

    init(address: String, name: String) {
        self.address = address
        warning = ScamInfo(name: name, address: address, type: .lowScore, subtype: "Controlled public fixture")
        started = XCTestExpectation(description: "warning lookup started for \(address)")
        returned = XCTestExpectation(description: "warning lookup returned for \(address)")
    }

    func release(warning: ScamInfo?) throws {
        let pending = try XCTUnwrap(continuation)
        continuation = nil
        pending.resume(returning: warning)
    }

    func close() {
        continuation?.resume(returning: nil)
        continuation = nil
    }
}

@MainActor
private final class SendScamWarningFetcher: ScamInfoFetching {
    var requests: [SendScamWarningRequest]
    private var closed = false

    init(requests: [SendScamWarningRequest]) { self.requests = requests }

    func fetch(address: String, chain: ChainModel) async throws -> ScamInfo? {
        guard !closed else { return nil }
        guard let request = requests.first(where: { $0.address == address && $0.observedChainId == nil }) else {
            XCTFail("Unexpected warning request address: \(address)")
            return nil
        }
        let value = await withCheckedContinuation { continuation in
            XCTAssertNil(request.observedChainId, "Each selected recipient has one expected lookup")
            request.observedChainId = chain.chainId
            request.continuation = continuation
            request.started.fulfill()
        }
        // Same actor as SendInteractor's caller. Its guard/output call follows this return;
        // the test drains the main queue after this checkpoint to observe the real view bind.
        DispatchQueue.main.async { request.returned.fulfill() }
        return value
    }

    func close() {
        closed = true
        requests.forEach { $0.close() }
    }
}

@MainActor
private final class SendScamWarningDependencyGate {
    private var pending: [CheckedContinuation<SendDependencies, Error>] = []
    private var closed = false

    func wait() async throws -> SendDependencies {
        guard !closed else { throw CancellationError() }
        return try await withCheckedThrowingContinuation { pending.append($0) }
    }

    func close() {
        closed = true
        let continuations = pending
        pending.removeAll()
        continuations.forEach { $0.resume(throwing: CancellationError()) }
    }
}

private struct SendScamWarningScoreFetcher: AccountStatisticsFetching {
    func subscribeForStatistics(address: String) async throws -> AsyncThrowingStream<AccountStatisticsResponse, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(AccountStatisticsResponse(data: AccountStatistics(score: 0.8, address: address, stats: nil)))
            continuation.finish()
        }
    }

    func fetchStatistics(address _: String) async throws -> AccountStatisticsResponse? { nil }
}

private extension SendInteractorStub {
    func invalidateScamInfo() {}
}

extension SendDependencyErrorSurfacingTests {
    @MainActor
    func testSendScamWarningDisplayedWarningRetiresOnActualClear() async throws {
        let fixture = try makeScamWarningOwnershipFixture()
        defer { fixture.close() }
        fixture.presenter.didSelect(address: fixture.first.address)
        await fulfillment(of: [fixture.first.started], timeout: 2)
        try fixture.first.release(warning: fixture.first.warning)
        await fulfillment(of: [fixture.first.returned], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertFalse(fixture.controller.rootView.scamWarningView.isHidden)
        try nativeRecipientButton("clean", in: fixture.controller.rootView.searchView).sendActions(for: .touchUpInside)
        await drainNativeAmountQueue()
        XCTAssertTrue(fixture.controller.rootView.searchView.textField.text?.isEmpty != false)
        XCTAssertTrue(fixture.controller.rootView.scamWarningView.isHidden)
    }

    @MainActor
    func testSendScamWarningQueuedPresenterDeliveryCannotRepaintAfterClear() async throws {
        let fixture = try makeScamWarningOwnershipFixture()
        defer { fixture.close() }
        fixture.presenter.didSelect(address: fixture.first.address)
        await fulfillment(of: [fixture.first.started], timeout: 2)
        await drainNativeAmountQueue()
        // Directly isolates the already-accepted presenter-to-view queue boundary.
        // There is no actor suspension between enqueueing the warning and actual Clear.
        fixture.presenter.didReceive(scamInfo: fixture.first.warning)
        let betweenDeliveries = XCTestExpectation(description: "Retired warning never repaints before queued clear")
        DispatchQueue.main.async {
            XCTAssertTrue(fixture.controller.rootView.scamWarningView.isHidden)
            betweenDeliveries.fulfill()
        }
        try nativeRecipientButton("clean", in: fixture.controller.rootView.searchView).sendActions(for: .touchUpInside)
        await fulfillment(of: [betweenDeliveries], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertTrue(fixture.controller.rootView.scamWarningView.isHidden)
        try fixture.first.release(warning: fixture.first.warning)
        await fulfillment(of: [fixture.first.returned], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertTrue(fixture.controller.rootView.scamWarningView.isHidden)
    }

    @MainActor
    func testSendScamWarningRecipientRoundTripRejectsBothOlderRequests() async throws {
        let fixture = try makeScamWarningOwnershipFixture()
        defer { fixture.close() }
        let latest = SendScamWarningRequest(address: fixture.first.address, name: "Public warning fresh A")
        fixture.warnings.requests.append(latest)
        fixture.presenter.didSelect(address: fixture.first.address)
        await fulfillment(of: [fixture.first.started], timeout: 2)
        fixture.presenter.didSelect(address: fixture.second.address)
        await fulfillment(of: [fixture.second.started], timeout: 2)
        fixture.presenter.didSelect(address: latest.address)
        await fulfillment(of: [latest.started], timeout: 2)
        try fixture.first.release(warning: fixture.first.warning)
        try fixture.second.release(warning: fixture.second.warning)
        await fulfillment(of: [fixture.first.returned, fixture.second.returned], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertEqual(fixture.controller.rootView.searchView.textField.text, latest.address)
        XCTAssertTrue(latest.isHeld)
        XCTAssertTrue(fixture.controller.rootView.scamWarningView.isHidden)
        try latest.release(warning: latest.warning)
        await fulfillment(of: [latest.returned], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertFalse(fixture.controller.rootView.scamWarningView.isHidden)
        XCTAssertTrue(scamWarningLabels(in: fixture.controller.rootView.scamWarningView).contains(latest.warning.name))
    }

    @MainActor
    func testSendScamWarningDisplayedWarningRetiresOnChainSelection() async throws {
        let fixture = try makeScamWarningOwnershipFixture()
        defer { fixture.close() }
        let other = try XCTUnwrap(SendNetworkFixture.assets().first { $0.chain.chainId == "137" && $0.isUtility })
        let latest = SendScamWarningRequest(address: fixture.first.address, name: "Public warning new chain")
        fixture.warnings.requests.append(latest)
        fixture.presenter.didSelect(address: fixture.first.address)
        await fulfillment(of: [fixture.first.started], timeout: 2)
        try fixture.first.release(warning: fixture.first.warning)
        await fulfillment(of: [fixture.first.returned], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertFalse(fixture.controller.rootView.scamWarningView.isHidden)
        fixture.presenter.assetSelection(didCompleteWith: other, contextTag: nil)
        await fulfillment(of: [latest.started], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertEqual(latest.observedChainId, other.chain.chainId)
        XCTAssertTrue(latest.isHeld)
        XCTAssertTrue(fixture.controller.rootView.scamWarningView.isHidden)
        try latest.release(warning: latest.warning)
        await fulfillment(of: [latest.returned], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertFalse(fixture.controller.rootView.scamWarningView.isHidden)
        XCTAssertTrue(scamWarningLabels(in: fixture.controller.rootView.scamWarningView).contains(latest.warning.name))
    }

    @MainActor
    func testSendScamWarningHeldResponseCannotCrossChainSelection() async throws {
        let fixture = try makeScamWarningOwnershipFixture()
        defer { fixture.close() }
        let other = try XCTUnwrap(SendNetworkFixture.assets().first { $0.chain.chainId == "137" && $0.isUtility })
        let latest = SendScamWarningRequest(address: fixture.first.address, name: "Public warning new chain")
        fixture.warnings.requests.append(latest)
        fixture.presenter.didSelect(address: fixture.first.address)
        await fulfillment(of: [fixture.first.started], timeout: 2)
        fixture.presenter.assetSelection(didCompleteWith: other, contextTag: nil)
        await fulfillment(of: [latest.started], timeout: 2)
        try fixture.first.release(warning: fixture.first.warning)
        await fulfillment(of: [fixture.first.returned], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertEqual(latest.observedChainId, other.chain.chainId)
        XCTAssertTrue(latest.isHeld)
        XCTAssertTrue(fixture.controller.rootView.scamWarningView.isHidden)
        try latest.release(warning: latest.warning)
        await fulfillment(of: [latest.returned], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertFalse(fixture.controller.rootView.scamWarningView.isHidden)
        XCTAssertTrue(scamWarningLabels(in: fixture.controller.rootView.scamWarningView).contains(latest.warning.name))
    }

    @MainActor
    func testSendScamWarningCurrentNilResponseClearsPreviousWarning() async throws {
        let fixture = try makeScamWarningOwnershipFixture()
        defer { fixture.close() }
        let refreshed = SendScamWarningRequest(address: fixture.first.address, name: "Unused public warning")
        fixture.warnings.requests.append(refreshed)
        fixture.presenter.didSelect(address: fixture.first.address)
        await fulfillment(of: [fixture.first.started], timeout: 2)
        try fixture.first.release(warning: fixture.first.warning)
        await fulfillment(of: [fixture.first.returned], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertFalse(fixture.controller.rootView.scamWarningView.isHidden)
        fixture.presenter.didSelect(address: refreshed.address)
        await fulfillment(of: [refreshed.started], timeout: 2)
        try refreshed.release(warning: nil)
        await fulfillment(of: [refreshed.returned], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertEqual(fixture.controller.rootView.searchView.textField.text, refreshed.address)
        XCTAssertTrue(fixture.controller.rootView.scamWarningView.isHidden)
    }

    @MainActor
    func testSendScamWarningInvalidationBeforeTaskStartAvoidsObsoleteLookup() async throws {
        let fixture = try makeScamWarningOwnershipFixture()
        defer { fixture.close() }
        fixture.presenter.didSelect(address: fixture.first.address)
        fixture.presenter.didSelect(address: fixture.second.address)
        await fulfillment(of: [fixture.second.started], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertNil(fixture.first.observedChainId)
        XCTAssertFalse(fixture.first.isHeld)
        try fixture.second.release(warning: fixture.second.warning)
        await fulfillment(of: [fixture.second.returned], timeout: 2)
        await drainNativeAmountQueue()
        XCTAssertFalse(fixture.controller.rootView.scamWarningView.isHidden)
        XCTAssertTrue(
            scamWarningLabels(in: fixture.controller.rootView.scamWarningView).contains(fixture.second.warning.name)
        )
    }
}
