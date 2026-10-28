import BigInt
import IrohaCrypto
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import SSFXCM
import SoraFoundation
import UIKit
import XCTest
@testable import fearless

/// The reviewed Liberland to SORA routes against the production registry snapshot and Liberland's live runtime
/// metadata: destination resolution and form readiness, call pinning, the minimum and recipient rules, and the
/// in-doubt submission journal.
final class CrossChainReviewedRouteTests: XCTestCase {
    private static let liberlandId = ReviewedXcmRouteRegistry.liberlandChainId
    private static let soraId = ReviewedXcmRouteRegistry.soraChainId

    // MARK: - Production registry

    func testLiveLiberlandRoutesResolveAgainstTheProductionRegistryAndNothingRetiredDoes() throws {
        let chains = try Self.registryChains()
        let chainsById = Dictionary(uniqueKeysWithValues: chains.map { ($0.chainId, $0) })
        let sora = try XCTUnwrap(chainsById[Self.soraId])
        let expectedDestinations: [String: (catalogId: String, currencyId: String)] = [
            "LLM": ("0ef3afdc-cdd3-47cc-bd52-817c54ae65b5", "0x00073edd278e1bd6a7f9d0b27d4f3e93b73c8f0832b58a4df13c69611a99f156"),
            "XOR": ("b774c386-5cce-454a-a845-1ec0381538ec", "0x0200000000000000000000000000000000000000000000000000000000000000"),
            "LLD": ("1c3b4fcb-5a5f-4319-9dce-d178006eb9bf", "0x00513be65493a7fc3e2128d4230061a530acf40478a4affa20bbba27a310673e")
        ]

        XCTAssertEqual(Set(ReviewedXcmRouteRegistry.routes.map(\.originSymbol)), Set(expectedDestinations.keys))
        for definition in ReviewedXcmRouteRegistry.routes {
            let (origin, destinationNames) = try XCTUnwrap(
                ReviewedXcmRouteRegistry.validatedOrigin(for: definition, chainsById: chainsById),
                definition.originSymbol
            )
            XCTAssertEqual(destinationNames, ["SORA Mainnet"])
            XCTAssertEqual(origin.asset.id, definition.originAssetId)

            // The recipient receives SORA's own catalog row, whose ID differs from the origin's.
            let destination = try XCTUnwrap(
                ReviewedXcmRouteRegistry.destinationChainAsset(for: definition, in: sora),
                definition.originSymbol
            )
            let expected = try XCTUnwrap(expectedDestinations[definition.originSymbol])
            XCTAssertEqual(destination.asset.id, expected.catalogId)
            XCTAssertEqual(destination.asset.currencyId, expected.currencyId)
            XCTAssertNotEqual(destination.asset.id, origin.asset.id)
            XCTAssertEqual(definition.execution.callIndex, ReviewedXcmRouteRegistry.liberlandSoraBridgeAppBurnIndex)

            let context = ReviewedCrossChainRouteContext(
                definition: definition,
                providerId: ReviewedXcmRouteRegistry.providerId(for: definition)
            )
            XCTAssertTrue(context.validates(origin: origin, destination: sora), definition.originSymbol)
            XCTAssertNoThrow(
                try ReviewedCrossChainSubmissionValidator.validate(
                    origin: origin,
                    destination: sora,
                    reviewedRoute: context,
                    mutationsEnabled: true,
                    executionAdapterAvailable: true
                ),
                definition.originSymbol
            )
        }

        let wallet = AccountGenerator.generateMetaAccount()
        let liberlandOrigins = LiberlandXcmRouteProvider(isExecutionAvailable: true).origins(wallet: wallet, chains: chains)
        XCTAssertEqual(Set(liberlandOrigins.map(\.chainAsset.asset.symbolUppercased)), ["LLD", "LLM", "XOR"])
        XCTAssertTrue(SoraSubstrateBridgeRouteProvider().origins(wallet: wallet, chains: chains).isEmpty)

        for definition in ReviewedXcmRouteRegistry.retiredRoutes {
            let context = ReviewedCrossChainRouteContext(
                definition: definition,
                providerId: ReviewedXcmRouteRegistry.providerId(for: definition)
            )
            XCTAssertNil(ReviewedXcmRouteRegistry.definition(for: context), definition.originSymbol)
            XCTAssertNil(definition.execution.callIndex, definition.originSymbol)
            XCTAssertThrowsError(
                try ReviewedCrossChainCallLayout.expected(
                    execution: definition.execution,
                    destinationAccountId: Data(repeating: 1, count: 32),
                    amount: 1
                ),
                definition.originSymbol
            )
        }
    }

    func testWithoutBundledTrustTheReviewedRoutesAreShownAsNotAvailable() async throws {
        // Like every production build so far, the test build bundles no mutation trust.
        XCTAssertFalse(MutationAuthorizationReleaseBinding.isProvisioned(.xcm))
        XCTAssertFalse(ReviewedXcmExecutionAuthority.isAvailable)

        let chains = try Self.registryChains()
        let wallet = AccountGenerator.generateMetaAccount()
        let provider = LiberlandXcmRouteProvider()
        let origins = provider.origins(wallet: wallet, chains: chains)
        XCTAssertTrue(origins.isEmpty, "Nothing may be offered that this build cannot send")
        let capability = provider.capability(for: origins)
        XCTAssertFalse(capability.isAvailable)
        XCTAssertEqual(capability.reason, ReviewedXcmExecutionAuthority.unavailableReason)

        let rows = provider.reviewedUnavailableRoutes.filter { $0.originChainId == Self.liberlandId }
        XCTAssertEqual(rows.map(\.symbol).sorted(), ["LLD", "LLM", "XOR"])
        XCTAssertTrue(rows.allSatisfy {
            !$0.isExecutable && $0.unavailableReason == ReviewedXcmExecutionAuthority.unavailableReason &&
                $0.destinationChainId == Self.soraId
        })
        XCTAssertEqual(rows.first { $0.symbol == "LLD" }?.minimumDisplay, "1.1 LLD")
        XCTAssertEqual(
            provider.reviewedUnavailableRoutes.count,
            rows.count + LiberlandXcmRouteProvider(isExecutionAvailable: true).reviewedUnavailableRoutes.count
        )

        // The provider row names the version, not a remote switch.
        let root = CrossChainRootViewController(wallet: wallet, providers: [provider])
        root.loadViewIfNeeded()
        let table = UITableView()
        table.register(UITableViewCell.self, forCellReuseIdentifier: "CrossChainOriginCell")
        let providerRow = root.tableView(table, cellForRowAt: IndexPath(row: 0, section: 1))
        let providerText = (providerRow.contentConfiguration as? UIListContentConfiguration)?.secondaryText
        XCTAssertEqual(providerText, ReviewedXcmExecutionAuthority.unavailableReason)

        // No form opens, and every later check reports the version rather than the switch.
        let definition = try XCTUnwrap(ReviewedXcmRouteRegistry.routes.first { $0.originSymbol == "LLD" })
        let context = ReviewedCrossChainRouteContext(definition: definition, providerId: "sora-liberland-xcm")
        let origin = try XCTUnwrap(
            chains.first { $0.chainId == Self.liberlandId }?.chainAssets.first { $0.asset.id == definition.originAssetId }
        )
        let sora = try XCTUnwrap(chains.first { $0.chainId == Self.soraId })
        XCTAssertNil(CrossChainAssembly.configureModule(with: origin, wallet: wallet, reviewedRoute: context))
        XCTAssertThrowsError(
            try ReviewedCrossChainSubmissionValidator.validate(
                origin: origin,
                destination: sora,
                reviewedRoute: context,
                mutationsEnabled: false
            )
        ) { error in
            XCTAssertEqual(error as? ReviewedCrossChainSubmissionError, .executionAdapterUnavailable)
        }
        let data = try makeConfirmationData()
        let authorizer = ReviewedCrossChainSubmissionAuthorizer(
            data: data,
            destinationFeeProvider: DestinationFeeStub(),
            selectedWallet: { data.wallet },
            mutationsEnabled: { false }
        )
        do {
            _ = try await authorizer.authorize()
            XCTFail("An unprovisioned build must not authorize")
        } catch {
            XCTAssertEqual(error as? ReviewedCrossChainSubmissionError, .executionAdapterUnavailable)
        }
        XCTAssertEqual(
            ReviewedCrossChainSubmissionError.executionAdapterUnavailable.localizedDescription,
            ReviewedXcmExecutionAuthority.unavailableReason
        )
        try assertEveryBundledLocalizationHas("cross_chain.unavailable_in_version")
    }

    func testDestinationIsNeverFoundByTheOriginAssetIdOrSymbol() throws {
        let chains = try Self.registryChains()
        let sora = try XCTUnwrap(chains.first { $0.chainId == Self.soraId })
        let lld = try XCTUnwrap(ReviewedXcmRouteRegistry.routes.first { $0.originSymbol == "LLD" })

        let impostorSora = sora.replacingAssets(
            sora.assets.filter { $0.id != lld.execution.destinationAsset?.catalogAssetId }.union([
                // Same symbol and the origin's catalog ID, but not the reviewed SORA row.
                AssetModel(
                    id: lld.originAssetId,
                    name: "LLD",
                    symbol: "LLD",
                    precision: 18,
                    currencyId: "0x00513be65493a7fc3e2128d4230061a530acf40478a4affa20bbba27a310673e",
                    isUtility: false,
                    isNative: false
                )
            ])
        )

        XCTAssertNil(ReviewedXcmRouteRegistry.destinationChainAsset(for: lld, in: impostorSora))
        let origin = try XCTUnwrap(
            chains.first { $0.chainId == Self.liberlandId }?.chainAssets.first { $0.asset.id == lld.originAssetId }
        )
        XCTAssertFalse(
            ReviewedCrossChainRouteContext(definition: lld, providerId: "sora-liberland-xcm")
                .validates(origin: origin, destination: impostorSora)
        )
    }

    // MARK: - Form readiness

    func testInteractorAlwaysAnswersTheDestinationMinimum() throws {
        let chains = try Self.registryChains()
        let sora = try XCTUnwrap(chains.first { $0.chainId == Self.soraId })

        for symbol in ["LLD", "LLM"] {
            let (interactor, output) = try makeInteractor(symbol: symbol)
            let answered = expectation(description: "\(symbol) destination minimum")
            output.onDestinationExistentialDeposit = { answered.fulfill() }
            interactor.didReceive(destinationChain: sora)
            wait(for: [answered], timeout: 2)
            // SORA's Tokens pallet keeps no minimum balance.
            XCTAssertEqual(try output.destinationExistentialDeposit?.get(), .zero, symbol)
        }

        // XOR uses SORA's Balances constant, which needs the destination runtime; without it the form gets an error
        // rather than silence.
        let (xorInteractor, xorOutput) = try makeInteractor(symbol: "XOR")
        let xorAnswered = expectation(description: "XOR destination minimum")
        xorOutput.onDestinationExistentialDeposit = { xorAnswered.fulfill() }
        xorInteractor.didReceive(destinationChain: sora)
        wait(for: [xorAnswered], timeout: 2)
        XCTAssertThrowsError(try xorOutput.destinationExistentialDeposit?.get())

        let (lldInteractor, lldOutput) = try makeInteractor(symbol: "LLD")
        let lld = try XCTUnwrap(ReviewedXcmRouteRegistry.routes.first { $0.originSymbol == "LLD" })
        let soraWithoutLld = sora.replacingAssets(
            sora.assets.filter { $0.id != lld.execution.destinationAsset?.catalogAssetId }
        )
        let missingAnswered = expectation(description: "missing destination asset")
        lldOutput.onDestinationExistentialDeposit = { missingAnswered.fulfill() }
        lldInteractor.didReceive(destinationChain: soraWithoutLld)
        wait(for: [missingAnswered], timeout: 2)
        XCTAssertThrowsError(try lldOutput.destinationExistentialDeposit?.get()) { error in
            XCTAssertEqual(error as? CrossChainFormError, .destinationAssetUnavailable)
        }
    }

    func testFormBecomesReadyForTheLiveRouteWithProductionChains() throws {
        let harness = try PresenterHarness(symbol: "LLM")
        harness.loadAndSelectSora()
        XCTAssertEqual(harness.interactor.receivedDestinations.map(\.chainId), [Self.soraId])

        harness.feedReadyState(balance: "10", utilityBalance: "5")

        XCTAssertEqual(harness.view.buttonLoadingStates.last, false)
    }

    func testFailedQuotesAndAnUnresolvedDestinationEndTheSpinnerWithAnExplanation() throws {
        let harness = try PresenterHarness(symbol: "LLD")
        harness.loadAndSelectSora()
        harness.feedReadyState(balance: "10", utilityBalance: "10")
        harness.presenter.didReceiveOriginFee(result: .failure(ReviewedCrossChainSubmissionError.runtimeUnavailable))
        harness.presenter.didReceiveDestinationExistentialDeposit(
            result: .failure(CrossChainFormError.destinationAssetUnavailable)
        )
        XCTAssertEqual(harness.view.buttonLoadingStates.last, false)

        harness.presenter.searchTextDidChanged(harness.soraAddress(byte: 7))
        harness.presenter.updateAmount(2)
        harness.presenter.didTapContinueButton()

        XCTAssertNil(harness.router.confirmationData)
        XCTAssertEqual(
            harness.router.messages.last,
            CrossChainFormError.destinationAssetUnavailable.localizedDescription
        )
    }

    func testUtilityMinimumIsNotSubtractedFromAnotherAssetsBalance() throws {
        let harness = try PresenterHarness(symbol: "LLM")
        harness.loadAndSelectSora()
        harness.feedReadyState(balance: "10", utilityBalance: "5")
        harness.presenter.searchTextDidChanged(harness.soraAddress(byte: 7))

        harness.presenter.selectAmountPercentage(1)
        harness.feedFees()
        harness.presenter.didTapContinueButton()

        // Liberland's existential deposit is 1 LLD; it binds LLD only, so 100% of LLM is all of it.
        let data = try XCTUnwrap(harness.router.confirmationData)
        XCTAssertEqual(data.amount, BigUInt(10) * BigUInt(10).power(12))
    }

    func testAPercentageSignsExactlyTheAmountTheConfirmationShows() throws {
        let harness = try PresenterHarness(symbol: "LLM")
        harness.loadAndSelectSora()
        // 1.234567891234 LLM: half of it has more decimals than the amount field shows.
        harness.feedReadyState(balance: "1.234567891234", utilityBalance: "5")
        harness.presenter.searchTextDidChanged(harness.soraAddress(byte: 7))

        harness.presenter.selectAmountPercentage(0.5)
        harness.feedFees()
        harness.presenter.didTapContinueButton()

        let data = try XCTUnwrap(harness.router.confirmationData)
        XCTAssertEqual(data.amount, BigUInt(617_283_000_000))
        let shown = try XCTUnwrap(
            Decimal(string: data.displayAmount.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US"))
        )
        XCTAssertEqual(shown.toSubstrateAmount(precision: 12), data.amount)
    }

    func testSystemAccountsAreRefusedAsRecipients() throws {
        let harness = try PresenterHarness(symbol: "LLD")
        harness.loadAndSelectSora()
        harness.feedReadyState(balance: "10", utilityBalance: "10")

        var moduleAccount = Data("modl".utf8) + Data("py/trsry".utf8)
        moduleAccount.append(Data(repeating: 0, count: 32 - moduleAccount.count))
        let address = try AddressFactory.address(for: moduleAccount, chain: harness.sora)
        harness.presenter.searchTextDidChanged(address)
        harness.presenter.updateAmount(2)
        harness.feedFees()
        harness.presenter.didTapContinueButton()

        XCTAssertNil(harness.router.confirmationData)
        XCTAssertEqual(
            harness.router.messages.last,
            ReviewedCrossChainSubmissionError.invalidRecipient.localizedDescription
        )
    }

    func testReviewedMinimumIsExactPerAssetAndDirectionAndFailsClosed() throws {
        let chains = try Self.registryChains()
        let liberland = try XCTUnwrap(chains.first { $0.chainId == Self.liberlandId })
        let sora = try XCTUnwrap(chains.first { $0.chainId == Self.soraId })
        let inspector = AppXcmMinAmountInspectorImpl()
        func origin(_ symbol: String) throws -> ChainAsset {
            try XCTUnwrap(liberland.chainAssets.first { $0.asset.symbolUppercased == symbol })
        }

        XCTAssertThrowsError(
            try inspector.inspectMin(amount: 1_099_999_999_999, origin: origin("LLD"), destination: sora)
        ) { error in
            XCTAssertEqual(error as? AppXcmMinAmountError, .minAmountError("1.1 LLD"))
        }
        XCTAssertNoThrow(try inspector.inspectMin(amount: 1_100_000_000_000, origin: origin("LLD"), destination: sora))
        // LLM and XOR have no reviewed minimum; the old rule applied "1.0 LLD" to every asset of the pair.
        XCTAssertNoThrow(try inspector.inspectMin(amount: 1, origin: origin("LLM"), destination: sora))
        XCTAssertNoThrow(try inspector.inspectMin(amount: 1, origin: origin("XOR"), destination: sora))

        // Unreviewed directions and drifted precision have no rule, and that stops the transfer.
        let soraXor = try XCTUnwrap(sora.chainAssets.first { $0.asset.symbolUppercased == "XOR" })
        XCTAssertThrowsError(try inspector.inspectMin(amount: 1, origin: soraXor, destination: liberland)) { error in
            XCTAssertEqual(error as? AppXcmMinAmountError, .ruleUnavailable)
        }
        let drifted = try origin("LLM")
        let driftedAsset = AssetModel(
            id: drifted.asset.id,
            name: drifted.asset.name,
            symbol: drifted.asset.symbol,
            precision: 18,
            currencyId: drifted.asset.currencyId,
            isUtility: false,
            isNative: false
        )
        XCTAssertThrowsError(
            try inspector.inspectMin(
                amount: 1,
                origin: ChainAsset(chain: liberland, asset: driftedAsset),
                destination: sora
            )
        ) { error in
            XCTAssertEqual(error as? AppXcmMinAmountError, .ruleUnavailable)
        }
    }

    // MARK: - Call pinning against Liberland's runtime

    func testLiberlandBurnEncodesToTheBytesTheLiveRuntimeProduces() throws {
        let factory = try Self.liberlandCoderFactory()
        let negotiator = ReviewedCrossChainRuntimeNegotiator()
        let recipient = Data(repeating: 1, count: 32)
        let recipientHex = String(repeating: "01", count: 32)
        let amountHex = "01" + String(repeating: "00", count: 15)
        // Read from the live node with polkadot.js on 2026-10-24 (method hex of an unsigned, never-sent call).
        let liveEncodings: [String: String] = [
            "LLD": "0x51030000" + "01" + recipientHex + amountHex,
            "LLM": "0x5103000101000000" + "01" + recipientHex + amountHex,
            "XOR": "0x51030001150b292e" + "01" + recipientHex + amountHex
        ]

        for definition in ReviewedXcmRouteRegistry.routes {
            let capability = try negotiator.negotiate(
                factory: factory,
                specVersion: 34,
                descriptor: definition.execution
            )
            XCTAssertEqual(capability.moduleName, "SoraBridgeApp")
            XCTAssertEqual(capability.callName, "burn")
            XCTAssertEqual(capability.callIndex, ReviewedCrossChainCallIndex(palletIndex: 81, callIndex: 3))

            let encoded = try ReviewedCrossChainCallBuilder().encodedCall(
                execution: definition.execution,
                capability: capability,
                destinationAccountId: recipient,
                amount: 1,
                factory: factory
            )
            XCTAssertEqual(encoded.toHex(includePrefix: true), liveEncodings[definition.originSymbol])
            XCTAssertEqual(
                encoded,
                try ReviewedCrossChainCallLayout.expected(
                    execution: definition.execution,
                    destinationAccountId: recipient,
                    amount: 1
                )
            )
        }
    }

    func testTheReviewedBurnIsSignedAgainstTheCatalogGenesisWithoutAskingTheNodeAgain() throws {
        let catalogGenesis = try Data(hexStringSSF: Self.liberlandId)
        // The node answers block 0 with another network's genesis hash.
        let nodeGenesis = try Data(hexStringSSF: Self.soraId)

        let pinned = try signReviewedBurn(
            pinnedGenesisHash: ReviewedCrossChainGenesisReader.signingGenesisHash(for: Self.liberlandId)
        )
        XCTAssertEqual(pinned.engine.blockHashRequests, [blockNumberHex(100)], "Only the era's block may be asked for")
        let payload = try XCTUnwrap(pinned.signer.payloads.first)
        XCTAssertEqual(pinned.signer.payloads.count, 1)
        XCTAssertNotNil(payload.range(of: catalogGenesis))
        XCTAssertNil(payload.range(of: nodeGenesis))
        XCTAssertNotNil(pinned.engine.submitted)

        // Without the pin the factory signs whatever the node says block 0 is.
        let unpinned = try signReviewedBurn(pinnedGenesisHash: nil)
        XCTAssertTrue(unpinned.engine.blockHashRequests.contains(blockNumberHex(0)))
        XCTAssertNotNil(try XCTUnwrap(unpinned.signer.payloads.first).range(of: nodeGenesis))

        XCTAssertEqual(
            ReviewedCrossChainGenesisReader.signingGenesisHash(for: Self.liberlandId.uppercased()),
            "0x" + Self.liberlandId
        )
        XCTAssertTrue(
            ReviewedCrossChainGenesisReader.matches(
                genesisHash: ReviewedCrossChainGenesisReader.signingGenesisHash(for: Self.liberlandId),
                chainId: Self.liberlandId
            )
        )
    }

    func testTheSignedExtrinsicEndsInExactlyTheAuthorizedCall() throws {
        let burn = try signReviewedBurn(
            pinnedGenesisHash: ReviewedCrossChainGenesisReader.signingGenesisHash(for: Self.liberlandId)
        )
        let extrinsic = try XCTUnwrap(burn.engine.submitted)
        XCTAssertTrue(MutationOperationAuthorization.extrinsic(extrinsic, endsWithCall: burn.call))

        let lld = try XCTUnwrap(ReviewedXcmRouteRegistry.routes.first { $0.originSymbol == "LLD" })
        let otherAmount = try ReviewedCrossChainCallLayout.expected(
            execution: lld.execution,
            destinationAccountId: Data(repeating: 7, count: 32),
            amount: 1_100_000_000_001
        )
        let otherRecipient = try ReviewedCrossChainCallLayout.expected(
            execution: lld.execution,
            destinationAccountId: Data(repeating: 8, count: 32),
            amount: 1_100_000_000_000
        )
        XCTAssertFalse(MutationOperationAuthorization.extrinsic(extrinsic, endsWithCall: otherAmount))
        XCTAssertFalse(MutationOperationAuthorization.extrinsic(extrinsic, endsWithCall: otherRecipient))
        XCTAssertFalse(MutationOperationAuthorization.extrinsic(extrinsic + Data([0]), endsWithCall: burn.call))
    }

    func testNegotiatorRefusesAnyOtherPalletOrCallIndex() throws {
        let factory = try Self.liberlandCoderFactory()
        let negotiator = ReviewedCrossChainRuntimeNegotiator()
        let lld = try XCTUnwrap(ReviewedXcmRouteRegistry.routes.first { $0.originSymbol == "LLD" })

        for callIndex in [
            nil,
            ReviewedCrossChainCallIndex(palletIndex: 80, callIndex: 3),
            ReviewedCrossChainCallIndex(palletIndex: 81, callIndex: 2)
        ] {
            var execution = lld.execution
            execution.callIndex = callIndex
            XCTAssertThrowsError(
                try negotiator.negotiate(factory: factory, specVersion: 34, descriptor: execution)
            ) { error in
                XCTAssertEqual(error as? ReviewedCrossChainSubmissionError, .runtimeCallUnavailable)
            }
        }

        // A retired SORA burn has no pallet on Liberland and no reviewed layout.
        let retired = try XCTUnwrap(ReviewedXcmRouteRegistry.retiredRoutes.first)
        XCTAssertThrowsError(try negotiator.negotiate(factory: factory, specVersion: 34, descriptor: retired.execution))
    }

    func testCallLayoutRejectsAmountsTheRuntimeCannotHold() throws {
        let lld = try XCTUnwrap(ReviewedXcmRouteRegistry.routes.first { $0.originSymbol == "LLD" })
        let recipient = Data(repeating: 1, count: 32)

        XCTAssertNoThrow(
            try ReviewedCrossChainCallLayout.expected(
                execution: lld.execution,
                destinationAccountId: recipient,
                amount: ReviewedCrossChainCallLayout.maximumAmount
            )
        )
        for amount in [BigUInt.zero, ReviewedCrossChainCallLayout.maximumAmount + 1] {
            XCTAssertThrowsError(
                try ReviewedCrossChainCallLayout.expected(execution: lld.execution, destinationAccountId: recipient, amount: amount)
            ) { error in
                XCTAssertEqual(error as? ReviewedCrossChainSubmissionError, .invalidAmount)
            }
        }
        XCTAssertThrowsError(
            try ReviewedCrossChainCallLayout.expected(
                execution: lld.execution,
                destinationAccountId: Data(repeating: 1, count: 20),
                amount: 1
            )
        ) { error in
            XCTAssertEqual(error as? ReviewedCrossChainSubmissionError, .invalidRecipient)
        }
    }

    func testDestinationFeeAboveTheAmountIsRefused() throws {
        let lld = try XCTUnwrap(ReviewedXcmRouteRegistry.routes.first { $0.originSymbol == "LLD" })
        let amount = BigUInt(2_000_000_000_000)
        // LLD is Liberland's utility asset, so the same balance pays the burn and the fee.
        let key = AssetKey(ecosystem: "substrate", chainId: lld.originChainId, assetId: lld.originAssetId)
        let balances = ReviewedCrossChainAuthoritativeBalances(
            originAssetKey: key,
            feeAssetKey: key,
            originSpendable: amount * 4,
            feeSpendable: amount * 4
        )

        XCTAssertNoThrow(
            try ReviewedCrossChainSubmissionBoundaryValidator.validate(
                definition: lld,
                requestedAmount: amount,
                burnAmount: amount * 2,
                balances: balances,
                originFee: 1
            )
        )
        XCTAssertThrowsError(
            try ReviewedCrossChainSubmissionBoundaryValidator.validate(
                definition: lld,
                requestedAmount: amount,
                burnAmount: amount * 2 + 1,
                balances: balances,
                originFee: 1
            )
        ) { error in
            XCTAssertEqual(error as? ReviewedCrossChainSubmissionError, .destinationFeeTooHigh)
        }
    }

    func testGenesisHashMustBeTheOriginChain() {
        XCTAssertTrue(
            ReviewedCrossChainGenesisReader.matches(
                genesisHash: "0x6BD89E052D67A45BB60A9A23E8581053D5E0D619F15CB9865946937E690C42D6",
                chainId: Self.liberlandId
            )
        )
        XCTAssertFalse(ReviewedCrossChainGenesisReader.matches(genesisHash: "0x" + Self.soraId, chainId: Self.liberlandId))
        XCTAssertFalse(ReviewedCrossChainGenesisReader.matches(genesisHash: "0x", chainId: Self.liberlandId))
        XCTAssertFalse(ReviewedCrossChainGenesisReader.matches(genesisHash: Self.liberlandId + "00", chainId: Self.liberlandId))
    }

    func testRecipientPolicyRefusesAccountsNoOneControls() {
        func account(_ prefix: String) -> Data {
            var data = Data(prefix.utf8)
            data.append(Data(repeating: 0x11, count: 32 - data.count))
            return data
        }

        XCTAssertTrue(ReviewedCrossChainRecipientPolicy.rejects(Data(repeating: 0, count: 32)))
        XCTAssertTrue(ReviewedCrossChainRecipientPolicy.rejects(account("modl")))
        XCTAssertTrue(ReviewedCrossChainRecipientPolicy.rejects(account("para")))
        XCTAssertTrue(ReviewedCrossChainRecipientPolicy.rejects(account("sibl")))
        XCTAssertTrue(ReviewedCrossChainRecipientPolicy.rejects(Data(repeating: 7, count: 20)))
        XCTAssertFalse(ReviewedCrossChainRecipientPolicy.rejects(Data(repeating: 7, count: 32)))
    }

    // MARK: - Submission journal and dispatch outcome

    func testTransferKeyIgnoresFeesButNotTheTransfer() throws {
        func key(amount: BigUInt = 5, recipient: UInt8 = 2) throws -> String {
            try ReviewedCrossChainTransferKey.make(
                walletId: "wallet",
                originChainId: Self.liberlandId,
                originAccountId: Data(repeating: 1, count: 32),
                routeId: "route",
                destinationChainId: Self.soraId,
                destinationAccountId: Data(repeating: recipient, count: 32),
                amount: amount
            )
        }

        XCTAssertEqual(try key(), try key())
        XCTAssertNotEqual(try key(), try key(amount: 6))
        XCTAssertNotEqual(try key(), try key(recipient: 3))
    }

    func testRecordIsWrittenBeforeHandOffAndStaysInDoubtWhenTheTransportFails() throws {
        let journal = makeJournal()
        let executor = ScriptedExecutor(submitError: JSONRPCEngineError.timeout)
        executor.onSubmit = {
            // The record must already exist while the extrinsic is being handed over.
            XCTAssertEqual((try? journal.unresolved(for: "transfer", now: Date()))?.first?.status, .submitting)
        }
        let output = try submit(executor: executor, journal: journal)

        XCTAssertEqual(output.error as? ReviewedCrossChainDispatchError, .submissionInDoubt)
        XCTAssertEqual(executor.submitCount, 1)
        XCTAssertEqual(try journal.unresolved(for: "transfer", now: Date()).first?.status, .inDoubt)
    }

    func testRepeatingAnUnresolvedTransferNeedsExplicitConfirmation() throws {
        let journal = makeJournal()
        let executor = ScriptedExecutor(outcome: .unknown)

        let first = try submit(executor: executor, journal: journal)
        XCTAssertEqual(first.result, .unconfirmed(extrinsicHash: "0xhash"))
        XCTAssertEqual(try journal.unresolved(for: "transfer", now: Date()).first?.extrinsicHash, "0xhash")

        let second = try submit(executor: executor, journal: journal)
        XCTAssertEqual(second.unresolved?.transferKey, "transfer")
        XCTAssertEqual(executor.submitCount, 1)

        let confirmed = try submit(executor: executor, journal: journal, confirmingRepeat: true)
        XCTAssertEqual(confirmed.result, .unconfirmed(extrinsicHash: "0xhash"))
        XCTAssertEqual(executor.submitCount, 2)

        // A day later the record no longer stands in the way.
        XCTAssertTrue(try journal.unresolved(for: "transfer", now: Date().addingTimeInterval(25 * 60 * 60)).isEmpty)
    }

    func testDispatchOutcomeDecidesWhatTheUserSees() throws {
        let failedJournal = makeJournal()
        let failed = try submit(executor: ScriptedExecutor(outcome: .failed(blockHash: "0xblock")), journal: failedJournal)
        XCTAssertEqual(failed.error as? ReviewedCrossChainDispatchError, .extrinsicFailed(extrinsicHash: "0xhash"))
        // Nothing was burned, so nothing should ask before a retry.
        XCTAssertTrue(try failedJournal.unresolved(for: "transfer", now: Date()).isEmpty)

        let succeededJournal = makeJournal()
        let succeeded = try submit(
            executor: ScriptedExecutor(outcome: .succeeded(blockHash: "0xblock")),
            journal: succeededJournal
        )
        XCTAssertEqual(succeeded.result, .awaitingBridge(extrinsicHash: "0xhash"))
        let record = try XCTUnwrap(try succeededJournal.unresolved(for: "transfer", now: Date()).first)
        XCTAssertEqual(record.status, .awaitingBridge)
        XCTAssertEqual(record.blockHash, "0xblock")

        let rejectedJournal = makeJournal()
        let rejection = try JSONDecoder().decode(
            JSONRPCError.self,
            from: Data(#"{"message":"1010: Invalid Transaction","code":1010}"#.utf8)
        )
        let rejected = try submit(executor: ScriptedExecutor(submitError: rejection), journal: rejectedJournal)
        XCTAssertTrue(rejected.error is JSONRPCError)
        XCTAssertTrue(try rejectedJournal.unresolved(for: "transfer", now: Date()).isEmpty)
    }

    func testOnlyExplicitAuthorRpcRefusalsProveNoAdmission() {
        for code in [1001, 1002, 1010, 1011, 1012, 1014, 1015, 1016, 1018, 1019, 1020, 1021] {
            XCTAssertTrue(CrossChainConfirmationInteractor.provesNothingWasSent(
                JSONRPCError(message: "Pool refusal", code: code, data: nil)
            ), "Expected explicit refusal for code \(code)")
        }
        for code in [1013, 1017, 1040, -32603, -32000, 9999] {
            XCTAssertFalse(CrossChainConfirmationInteractor.provesNothingWasSent(
                JSONRPCError(message: "1010: misleading message text", code: code, data: nil)
            ), "Unknown admission must remain uncertain for code \(code)")
        }
        XCTAssertFalse(CrossChainConfirmationInteractor.provesNothingWasSent(JSONRPCEngineError.timeout))
    }

    func testAlreadyImportedAndUnclassifiedRpcErrorsKeepTheJournalAndFenceRepeat() throws {
        for code in [1013, 1040, -32603] {
            let journal = makeJournal()
            let executor = ScriptedExecutor(submitError: JSONRPCError(message: "RPC failure", code: code, data: nil))
            let first = try submit(executor: executor, journal: journal)
            XCTAssertEqual(first.error as? ReviewedCrossChainDispatchError, .submissionInDoubt)
            XCTAssertEqual(executor.submitCount, 1)
            XCTAssertEqual(try journal.unresolved(for: "transfer", now: Date()).first?.status, .inDoubt)

            let repeated = try submit(executor: executor, journal: journal)
            XCTAssertEqual(repeated.unresolved?.transferKey, "transfer")
            XCTAssertNil(repeated.result)
            XCTAssertEqual(executor.submitCount, 1, "An uncertain RPC response cannot authorize a second submission")
        }
    }

    func testARepeatThatEndsInARefusalNeverClearsTheEarlierAttempt() throws {
        let rejection = JSONRPCError(message: "1010: Invalid Transaction", code: 1010, data: nil)
        let repeatEndings: [ScriptedExecutor] = [
            // The node refuses the repeat, for example because the first attempt already used the funds.
            ScriptedExecutor(submitError: rejection, extrinsicHash: "0xsecond"),
            // A local refusal right before hand-off.
            ScriptedExecutor(submitError: MutationAuthorizationError.denied, extrinsicHash: "0xsecond"),
            // The runtime rejects the repeat in its block.
            ScriptedExecutor(outcome: .failed(blockHash: "0xblock"), extrinsicHash: "0xsecond")
        ]

        for repeatExecutor in repeatEndings {
            let journal = makeJournal()
            let first = try submit(executor: ScriptedExecutor(outcome: .unknown, extrinsicHash: "0xfirst"), journal: journal)
            XCTAssertEqual(first.result, .unconfirmed(extrinsicHash: "0xfirst"))

            let repeated = try submit(executor: repeatExecutor, journal: journal, confirmingRepeat: true)
            XCTAssertNotNil(repeated.error)
            XCTAssertEqual(repeatExecutor.submitCount, 1)

            // The first attempt may have burned the funds, so a third try still has to ask.
            let third = ScriptedExecutor(outcome: .unknown, extrinsicHash: "0xthird")
            let fenced = try submit(executor: third, journal: journal)
            XCTAssertEqual(fenced.unresolvedAttempts.map(\.extrinsicHash), ["0xfirst"])
            XCTAssertEqual(third.submitCount, 0)
        }
    }

    func testEveryUnresolvedAttemptIsKeptAndShown() throws {
        let journal = makeJournal()
        _ = try submit(executor: ScriptedExecutor(outcome: .unknown, extrinsicHash: "0xfirst"), journal: journal)
        let second = ScriptedExecutor(submitError: JSONRPCEngineError.timeout, extrinsicHash: "0xsecond")
        let inDoubt = try submit(executor: second, journal: journal, confirmingRepeat: true)
        XCTAssertEqual(inDoubt.error as? ReviewedCrossChainDispatchError, .submissionInDoubt)

        let third = ScriptedExecutor(outcome: .unknown)
        let fenced = try submit(executor: third, journal: journal)
        XCTAssertEqual(third.submitCount, 0)
        XCTAssertEqual(fenced.unresolvedAttempts.count, 2)
        XCTAssertEqual(Set(fenced.unresolvedAttempts.map(\.status)), [.inDoubt])
        XCTAssertEqual(fenced.unresolvedAttempts.compactMap(\.extrinsicHash), ["0xfirst"])
        XCTAssertEqual(Set(fenced.unresolvedAttempts.compactMap(\.attemptId)).count, 2)
    }

    func testRecordsWrittenBeforeAttemptsWereKeptApartStillFence() throws {
        let suiteName = "CrossChainReviewedRouteTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date()
        // The format the journal wrote before it kept attempts apart: one record per transfer key, no attempt id.
        let legacy = #"{"transfer":{"createdAt":\#(Int(now.timeIntervalSince1970 * 1000)),"extrinsicHash":"0xlegacy","intentSha256":"\#(String(repeating: "b", count: 64))","status":"inDoubt","summary":"2 LLD","transferKey":"transfer","updatedAt":\#(Int(now.timeIntervalSince1970 * 1000))}}"#
        defaults.set(Data(legacy.utf8), forKey: "cross_chain.submission_journal.v1")
        let journal = ReviewedCrossChainSubmissionJournal(userDefaults: defaults, logger: nil)

        let legacyRecord = try XCTUnwrap(try journal.unresolved(for: "transfer", now: now).first)
        XCTAssertNil(legacyRecord.attemptId)
        XCTAssertEqual(legacyRecord.extrinsicHash, "0xlegacy")

        let refused = ScriptedExecutor(submitError: JSONRPCError(message: "Pool refusal", code: 1010, data: nil))
        _ = try submit(executor: refused, journal: journal, confirmingRepeat: true)
        XCTAssertEqual(try journal.unresolved(for: "transfer", now: Date()).map(\.extrinsicHash), ["0xlegacy"])
    }

    func testAnUnreadableJournalStopsNewTransfersForOneConfirmationWindow() throws {
        let suiteName = "CrossChainReviewedRouteTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("not a journal".utf8), forKey: "cross_chain.submission_journal.v1")
        let journal = ReviewedCrossChainSubmissionJournal(userDefaults: defaults, logger: nil)
        let executor = ScriptedExecutor(outcome: .unknown)

        // The damaged records may hold an attempt of this very transfer, so nothing is sent, not even a repeat.
        for confirmingRepeat in [false, true] {
            let refused = try submit(executor: executor, journal: journal, confirmingRepeat: confirmingRepeat)
            XCTAssertEqual(refused.error as? ReviewedCrossChainDispatchError, .journalUnreadable)
        }
        XCTAssertEqual(executor.submitCount, 0)
        XCTAssertThrowsError(try journal.unresolved(for: "transfer", now: Date().addingTimeInterval(23 * 60 * 60)))
        XCTAssertNotNil(defaults.data(forKey: "cross_chain.submission_journal.v1.unreadable"))

        // A day after the damage was found, none of those records could still stand in the way.
        let dayLater = Date().addingTimeInterval(25 * 60 * 60)
        let resumed = try submit(executor: executor, journal: journal, now: { dayLater })
        XCTAssertEqual(resumed.result, .unconfirmed(extrinsicHash: "0xhash"))
        XCTAssertEqual(executor.submitCount, 1)
        XCTAssertNil(defaults.data(forKey: "cross_chain.submission_journal.v1.unreadable"))
        XCTAssertEqual(try journal.unresolved(for: "transfer", now: dayLater).count, 1)
        try assertEveryBundledLocalizationHas("cross_chain.dispatch.journal_unreadable")
    }

    func testDispatchWatcherReadsTheExtrinsicsOwnEvents() throws {
        let extrinsics = ["0x0401", "0x0502", "0x0603"]
        let hash = try Data(hexStringSSF: "0x0502").blake2b32().toHex(includePrefix: true)
        XCTAssertEqual(ReviewedCrossChainDispatchWatcher.index(of: hash.uppercased(), in: extrinsics), 1)
        XCTAssertNil(ReviewedCrossChainDispatchWatcher.index(of: "0x00", in: extrinsics))

        func records(_ events: [(UInt32, String)]) throws -> [EventRecord] {
            let json = events.map { index, method in
                #"{"phase":["ApplyExtrinsic","\#(index)"],"event":["System",["\#(method)",{}]]}"#
            }
            return try JSONDecoder().decode([EventRecord].self, from: Data("[\(json.joined(separator: ","))]".utf8))
        }

        XCTAssertEqual(
            ReviewedCrossChainDispatchWatcher.outcome(
                of: try records([(0, "ExtrinsicSuccess"), (1, "ExtrinsicFailed")]),
                extrinsicIndex: 1,
                blockHash: "0xblock"
            ),
            .failed(blockHash: "0xblock")
        )
        XCTAssertEqual(
            ReviewedCrossChainDispatchWatcher.outcome(
                of: try records([(0, "ExtrinsicFailed"), (1, "ExtrinsicSuccess")]),
                extrinsicIndex: 1,
                blockHash: "0xblock"
            ),
            .succeeded(blockHash: "0xblock")
        )
        XCTAssertEqual(
            ReviewedCrossChainDispatchWatcher.outcome(
                of: try records([(0, "ExtrinsicSuccess")]),
                extrinsicIndex: 1,
                blockHash: "0xblock"
            ),
            .unknown
        )
    }

    func testDispatchWatcherReadsALiberlandBlockWithTheAppRuntime() throws {
        let url = try XCTUnwrap(Bundle(for: CrossChainReviewedRouteTests.self).url(
            forResource: "liberland-block-18541863", withExtension: "json", subdirectory: "Registry"
        ))
        let block = try JSONDecoder().decode(LiberlandBlockFixture.self, from: Data(contentsOf: url))
        XCTAssertEqual(block.specVersion, 34)

        // The block's raw System.Events, decoded as the watcher does with Liberland's runtime and production types.
        let records = try ReviewedCrossChainDispatchWatcher.decodeEvents(
            try Data(hexStringSSF: block.events),
            factory: try Self.liberlandCoderFactory()
        )
        let hash = try Data(hexStringSSF: block.extrinsics[block.extrinsicIndex]).blake2b32().toHex(includePrefix: true)
        let index = try XCTUnwrap(ReviewedCrossChainDispatchWatcher.index(of: hash, in: block.extrinsics))
        XCTAssertEqual(index, block.extrinsicIndex)

        let own = records.filter { $0.extrinsicIndex == UInt32(index) }
        XCTAssertEqual(own.count, block.methods.count)
        XCTAssertEqual(own.last.map { "\($0.event.section).\($0.event.method)" }, "System.ExtrinsicSuccess")
        XCTAssertEqual(
            ReviewedCrossChainDispatchWatcher.outcome(of: records, extrinsicIndex: UInt32(index), blockHash: block.blockHash),
            .succeeded(blockHash: block.blockHash)
        )
    }

    func testDispatchWatcherReadsAFailedBurnWithTheAppRuntime() throws {
        // The same block's records for its timestamp extrinsic, plus a System.ExtrinsicFailed record for extrinsic 1
        // with DispatchError::Module { index: 81, error: 4 } (SoraBridgeApp's WrongAmount), encoded with the spec 34
        // types; see the Registry README.
        let url = try XCTUnwrap(Bundle(for: CrossChainReviewedRouteTests.self).url(
            forResource: "liberland-block-18541863-failed", withExtension: "json", subdirectory: "Registry"
        ))
        let block = try JSONDecoder().decode(LiberlandBlockFixture.self, from: Data(contentsOf: url))

        let records = try ReviewedCrossChainDispatchWatcher.decodeEvents(
            try Data(hexStringSSF: block.events),
            factory: try Self.liberlandCoderFactory()
        )

        XCTAssertEqual(
            ReviewedCrossChainDispatchWatcher.outcome(of: records, extrinsicIndex: 1, blockHash: block.blockHash),
            .failed(blockHash: block.blockHash)
        )
        XCTAssertEqual(
            ReviewedCrossChainDispatchWatcher.outcome(of: records, extrinsicIndex: 0, blockHash: block.blockHash),
            .succeeded(blockHash: block.blockHash)
        )
    }

    func testAFailureCountsOnlyFromAFinalizedBlock() async throws {
        let failed = try Self.blockFixture("liberland-block-18541863-failed")
        let succeeded = try Self.blockFixture("liberland-block-18541863")
        let inBlock = #"{"inBlock":"\#(failed.blockHash)"}"#
        let finalized = #"{"finalized":"\#(failed.blockHash)"}"#

        // Seen only in a best block, which can be retracted: the transfer stays in doubt.
        let bestBlockFailure = try await watchOutcome(of: failed, statuses: [inBlock])
        XCTAssertEqual(bestBlockFailure, .unknown)
        let endedSubscription = try await watchOutcome(of: failed, statuses: [inBlock], endsSubscription: true)
        XCTAssertEqual(endedSubscription, .unknown)
        let finalizedFailure = try await watchOutcome(of: failed, statuses: [inBlock, finalized])
        XCTAssertEqual(finalizedFailure, .failed(blockHash: failed.blockHash))

        // A success keeps the record either way, so a best block is enough to report it.
        let bestBlockSuccess = try await watchOutcome(of: succeeded, statuses: [inBlock])
        XCTAssertEqual(bestBlockSuccess, .succeeded(blockHash: succeeded.blockHash))
        let nothingIncluded = try await watchOutcome(of: succeeded, statuses: [#""ready""#])
        XCTAssertEqual(nothingIncluded, .unknown)

        XCTAssertEqual(
            ReviewedCrossChainDispatchWatcher.settled(.failed(blockHash: "0xblock"), isFinalized: false),
            .unknown
        )
        XCTAssertEqual(
            ReviewedCrossChainDispatchWatcher.settled(.failed(blockHash: "0xblock"), isFinalized: true),
            .failed(blockHash: "0xblock")
        )
    }

    // MARK: - Helpers

    private static var cachedChains: [ChainModel]?

    fileprivate static func blockFixture(_ name: String) throws -> LiberlandBlockFixture {
        let url = try XCTUnwrap(Bundle(for: CrossChainReviewedRouteTests.self).url(
            forResource: name, withExtension: "json", subdirectory: "Registry"
        ))
        return try JSONDecoder().decode(LiberlandBlockFixture.self, from: Data(contentsOf: url))
    }

    /// Every localization the app bundles carries `key`, so no language falls back to the key or another language.
    func assertEveryBundledLocalizationHas(_ key: String, file: StaticString = #filePath, line: UInt = #line) throws {
        for language in ["en", "id", "ja", "pt-PT", "ru", "tr", "vi", "zh-Hans"] {
            let bundle = try XCTUnwrap(
                Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)),
                language,
                file: file,
                line: line
            )
            let value = bundle.localizedString(forKey: key, value: "missing", table: nil)
            XCTAssertNotEqual(value, "missing", "\(language): \(key)", file: file, line: line)
            XCTAssertFalse(value.isEmpty, "\(language): \(key)", file: file, line: line)
        }
    }

    /// Builds, signs and submits the reviewed LLD burn through the app's extrinsic factory with Liberland's runtime,
    /// against a node that answers every read.
    private func signReviewedBurn(
        pinnedGenesisHash: String?,
        amount: BigUInt = 1_100_000_000_000
    ) throws -> (engine: ExtrinsicRPCRecorder, signer: PayloadRecordingSigner, call: Data) {
        let factory = try Self.liberlandCoderFactory()
        let lld = try XCTUnwrap(ReviewedXcmRouteRegistry.routes.first { $0.originSymbol == "LLD" })
        let capability = try ReviewedCrossChainRuntimeNegotiator().negotiate(
            factory: factory,
            specVersion: 34,
            descriptor: lld.execution
        )
        let recipient = Data(repeating: 7, count: 32)
        let engine = ExtrinsicRPCRecorder()
        let signer = PayloadRecordingSigner()
        let operationFactory = ExtrinsicOperationFactory(
            accountId: Data(repeating: 1, count: 32),
            chainFormat: .substrate(42),
            cryptoType: .sr25519,
            runtimeRegistry: RuntimeCodingServiceStub(factory: factory),
            engine: engine,
            pinnedGenesisHash: pinnedGenesisHash,
            eraOperationFactory: FixedEraOperationFactory()
        )
        let wrapper = operationFactory.submitAndWatch(
            try ReviewedCrossChainCallBuilder().builder(
                definition: lld,
                capability: capability,
                destinationAccountId: recipient,
                amount: amount
            ),
            signer: signer
        )
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        guard case let .success(submission)? = wrapper.targetOperation.result else {
            throw BaseOperationError.unexpectedDependentResult
        }
        XCTAssertEqual(try submission.result.get(), "subscription")
        let call = try ReviewedCrossChainCallLayout.expected(
            execution: lld.execution,
            destinationAccountId: recipient,
            amount: amount
        )
        return (engine, signer, call)
    }

    /// Runs the dispatch watcher against `block` while the node reports `statuses` for the block's signed extrinsic.
    private func watchOutcome(
        of block: LiberlandBlockFixture,
        statuses: [String],
        endsSubscription: Bool = false
    ) async throws -> ReviewedCrossChainDispatchOutcome {
        let engine = ScriptedWatchEngine(block: block, statuses: statuses, endsSubscription: endsSubscription)
        let watcher = ReviewedCrossChainDispatchWatcher(
            connection: engine,
            runtime: RuntimeCodingServiceStub(factory: try Self.liberlandCoderFactory()),
            timeout: 0.5
        )
        let hash = try Data(hexStringSSF: block.extrinsics[block.extrinsicIndex]).blake2b32().toHex(includePrefix: true)
        return await watcher.outcome(subscriptionId: "subscription", extrinsicHash: hash)
    }

    static func registryChains() throws -> [ChainModel] {
        if let cachedChains { return cachedChains }
        let url = try XCTUnwrap(Bundle(for: CrossChainReviewedRouteTests.self).url(
            forResource: "chains_v13_20261009", withExtension: "json", subdirectory: "Registry"
        ))
        let data = try Data(contentsOf: url)
        let chains: [ChainModel]
        if let decoded = try? JSONDecoder().decode([ChainModel].self, from: data) {
            chains = decoded
        } else {
            chains = try JSONDecoder().decode(
                [ChainModel].self,
                from: ChainSyncService.coerceChainsPayloadForCompatibility(data)
            )
        }
        cachedChains = chains
        return chains
    }

    /// Liberland's spec 34 metadata with its production chain types, built the way the app's runtime provider builds
    /// a snapshot, including the app's used runtime paths.
    static func liberlandCoderFactory() throws -> RuntimeCoderFactoryProtocol {
        let bundle = Bundle(for: CrossChainReviewedRouteTests.self)
        let metadataURL = try XCTUnwrap(
            bundle.url(forResource: "liberland-metadata-spec34", withExtension: "hex", subdirectory: "Registry")
        )
        let typesURL = try XCTUnwrap(
            bundle.url(forResource: "liberland-chain-types-20261024", withExtension: "json", subdirectory: "Registry")
        )
        let hex = try String(contentsOf: metadataURL).trimmingCharacters(in: .whitespacesAndNewlines)
        let metadata = try RuntimeMetadata(scaleDecoder: try ScaleDecoder(data: try Data(hexStringSSF: hex)))
        var usedRuntimePaths = UsedRuntimePaths()
        let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
            try JSONEncoder().encode(JSON.dictionaryValue(["types": .dictionaryValue([:])])),
            versioningData: try Data(contentsOf: typesURL),
            runtimeMetadata: metadata,
            usedRuntimePaths: usedRuntimePaths.usedRuntimePaths
        )
        return TestRuntimeCoderFactory(catalog: catalog, specVersion: 34, txVersion: 2, metadata: metadata)
    }

    private func makeInteractor(symbol: String) throws -> (CrossChainInteractor, CrossChainInteractorOutputSpy) {
        let chains = try Self.registryChains()
        let liberland = try XCTUnwrap(chains.first { $0.chainId == Self.liberlandId })
        let definition = try XCTUnwrap(ReviewedXcmRouteRegistry.routes.first { $0.originSymbol == symbol })
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = CrossChainInteractor(
            reviewedRoute: ReviewedCrossChainRouteContext(definition: definition, providerId: "sora-liberland-xcm"),
            chainAssetFetching: ChainAssetFetchingStub(chainAssets: chains.flatMap(\.chainAssets)),
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterStub(),
            depsContainer: CrossChainDepsContainer(wallet: wallet),
            originFeeEstimator: OriginFeeEstimatorStub(),
            runtimeItemRepository: AnyDataProviderRepository(EmptyRepository<fearless.RuntimeMetadataItem>()),
            operationQueue: OperationQueue(),
            logger: Logger.shared,
            wallet: wallet,
            addressChainDefiner: AddressChainDefiner(
                operationManager: OperationManager(),
                chainModelRepository: AnyDataProviderRepository(EmptyRepository<ChainModel>()),
                wallet: wallet
            ),
            existentialDepositService: ExistentialDepositServiceStub(),
            storageRequestPerformer: nil
        )
        let output = CrossChainInteractorOutputSpy()
        interactor.setup(with: output)
        _ = liberland
        return (interactor, output)
    }

    private func makeJournal() -> ReviewedCrossChainSubmissionJournal {
        let suiteName = "CrossChainReviewedRouteTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return ReviewedCrossChainSubmissionJournal(userDefaults: defaults, logger: nil)
    }

    private func submit(
        executor: ScriptedExecutor,
        journal: ReviewedCrossChainSubmissionJournal,
        confirmingRepeat: Bool = false,
        now: @escaping () -> Date = Date.init
    ) throws -> ConfirmationOutputSpy {
        let output = ConfirmationOutputSpy(expectation: expectation(description: "submission ended"))
        let interactor = CrossChainConfirmationInteractor(
            teleportData: try makeConfirmationData(),
            submissionAuthorizer: AuthorizerStub(
                submission: ReviewedCrossChainAuthorizedSubmission(
                    builder: { $0 },
                    executor: executor,
                    finalGuard: {},
                    transferKey: "transfer",
                    intentSha256: String(repeating: "b", count: 64)
                )
            ),
            journal: journal,
            operationQueue: OperationQueue(),
            logger: Logger.shared,
            mutationsEnabled: { true },
            now: now
        )
        interactor.setup(with: output)
        interactor.submit(confirmingRepeat: confirmingRepeat)
        wait(for: [output.expectation], timeout: 10)
        return output
    }

    private func makeConfirmationData() throws -> CrossChainConfirmationData {
        let chains = try Self.registryChains()
        let liberland = try XCTUnwrap(chains.first { $0.chainId == Self.liberlandId })
        let sora = try XCTUnwrap(chains.first { $0.chainId == Self.soraId })
        let definition = try XCTUnwrap(ReviewedXcmRouteRegistry.routes.first { $0.originSymbol == "LLD" })
        let origin = try XCTUnwrap(liberland.chainAssets.first { $0.asset.id == definition.originAssetId })
        return CrossChainConfirmationData(
            wallet: AccountGenerator.generateMetaAccount(),
            originChainAsset: origin,
            destChainModel: sora,
            amount: 2_000_000_000_000,
            displayAmount: "2",
            originChainFee: BalanceViewModel(amount: "0.01", price: nil),
            destChainFee: BalanceViewModel(amount: "0", price: nil),
            destChainFeeDecimal: .zero,
            recipientAddress: "recipient",
            reviewedRoute: ReviewedCrossChainRouteContext(definition: definition, providerId: "sora-liberland-xcm")
        )
    }
}

/// A Liberland block read on 2026-10-25 with `chain_getBlock` and `state_getStorage(System.Events)`, see the Registry README.
private struct LiberlandBlockFixture: Decodable {
    let blockNumber: Int
    let blockHash: String
    let extrinsicIndex: Int
    let extrinsics: [String]
    let events: String
    let methods: [String]
    let specVersion: Int
}

// MARK: - Presenter harness
// MARK: - Presenter harness

private final class PresenterHarness {
    let presenter: CrossChainPresenter
    let interactor = CrossChainInteractorStub()
    let router = CrossChainRouterSpy()
    let view = CrossChainViewSpy()
    let liberland: ChainModel
    let sora: ChainModel
    let origin: ChainAsset
    let utility: ChainAsset
    let wallet: MetaAccountModel

    init(symbol: String) throws {
        let chains = try CrossChainReviewedRouteTests.registryChains()
        liberland = try XCTUnwrap(chains.first { $0.chainId == ReviewedXcmRouteRegistry.liberlandChainId })
        sora = try XCTUnwrap(chains.first { $0.chainId == ReviewedXcmRouteRegistry.soraChainId })
        let definition = try XCTUnwrap(ReviewedXcmRouteRegistry.routes.first { $0.originSymbol == symbol })
        origin = try XCTUnwrap(liberland.chainAssets.first { $0.asset.id == definition.originAssetId })
        utility = try XCTUnwrap(liberland.utilityChainAssets().first)
        wallet = AccountGenerator.generateMetaAccount()

        let dataValidatingFactory = SendDataValidatingFactory(presentable: router)
        presenter = CrossChainPresenter(
            originChainAsset: origin,
            reviewedRoute: ReviewedCrossChainRouteContext(definition: definition, providerId: "sora-liberland-xcm"),
            wallet: wallet,
            viewModelFactory: CrossChainViewModelFactory(iconGenerator: UniversalIconGenerator()),
            dataValidatingFactory: dataValidatingFactory,
            logger: Logger.shared,
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared
        )
        dataValidatingFactory.view = view
    }

    func loadAndSelectSora() {
        presenter.didLoad(view: view)
        presenter.didSetup()
        presenter.didReceiveAvailableDestChainAssets(sora.chainAssets)
    }

    func feedReadyState(balance: String, utilityBalance: String) {
        let accountId = wallet.fetch(for: liberland.accountRequest())?.accountId ?? Data(repeating: 1, count: 32)
        presenter.didReceiveAccountInfo(
            result: .success(accountInfo(utilityBalance, precision: utility.asset.precision)),
            accountId: accountId,
            chainAsset: utility
        )
        presenter.didReceiveAccountInfo(
            result: .success(accountInfo(balance, precision: origin.asset.precision)),
            accountId: accountId,
            chainAsset: origin
        )
        // Liberland's existential deposit: 1 LLD.
        presenter.didReceiveExistentialDeposit(result: .success(BigUInt(10).power(12)))
        presenter.didReceiveAssetAccountInfo(assetAccountInfo: nil)
        presenter.didReceiveDestinationExistentialDeposit(result: .success(.zero))
        feedFees()
    }

    func feedFees() {
        presenter.didReceiveOriginFee(result: .success(BigUInt(10_000_000_000)))
        let fee = try? JSONDecoder().decode(
            DestXcmFee.self,
            from: Data(#"{"feeInPlanks":"0","symbol":"\#(origin.asset.symbolUppercased)","precision":"18"}"#.utf8)
        )
        presenter.didReceiveDestinationFee(result: fee.map { .success($0) } ?? .failure(CommonError.internal))
    }

    func soraAddress(byte: UInt8) -> String {
        (try? AddressFactory.address(for: Data(repeating: byte, count: 32), chain: sora)) ?? ""
    }

    private func accountInfo(_ amount: String, precision: UInt16) -> AccountInfo? {
        guard let planks = Decimal(string: amount, locale: Locale(identifier: "en_US"))?
            .toSubstrateAmount(precision: Int16(precision)) else {
            return nil
        }
        return AccountInfo(
            nonce: 0,
            consumers: 0,
            providers: 1,
            data: AccountData(free: planks, reserved: .zero, frozen: .zero)
        )
    }
}

private final class CrossChainInteractorStub: CrossChainInteractorInput {
    private(set) var receivedDestinations: [ChainModel] = []

    func setup(with _: CrossChainInteractorOutput) {}
    func didReceive(originChainAsset _: ChainAsset?) {}

    func didReceive(destinationChain: ChainModel) {
        receivedDestinations.append(destinationChain)
    }

    func estimateFee(originChainAsset _: ChainAsset, destinationChainModel _: ChainModel, amount _: Decimal?) {}

    func validate(address: String?, for chain: ChainModel) -> AddressValidationResult {
        guard let address, (try? AddressFactory.accountId(from: address, chain: chain)) != nil else {
            return .invalid(address)
        }
        return .valid(address)
    }

    func fetchDestinationAccountInfo(address _: String) {}
}

private final class CrossChainViewSpy: UIViewController, CrossChainViewInput, Localizable {
    private(set) var buttonLoadingStates: [Bool] = []

    func didReceive(assetBalanceViewModel _: AssetBalanceViewModelProtocol?) {}
    func didReceive(amountInputViewModel _: IAmountInputViewModel?) {}
    func didReceive(originSelectNetworkViewModel _: SelectNetworkViewModel) {}
    func didReceive(destSelectNetworkViewModel _: SelectNetworkViewModel?) {}
    func didReceive(originFeeViewModel _: LocalizableResource<BalanceViewModelProtocol>?) {}
    func didReceive(destinationFeeViewModel _: LocalizableResource<BalanceViewModelProtocol>?) {}
    func didReceive(recipientViewModel _: RecipientViewModel) {}

    func setButtonLoadingState(isLoading: Bool) {
        buttonLoadingStates.append(isLoading)
    }

    func applyLocalization() {}
}

private final class CrossChainRouterSpy: CrossChainRouterInput {
    private(set) var confirmationData: CrossChainConfirmationData?
    private(set) var messages: [String] = []

    func showSelectNetwork(
        from _: ControllerBackedProtocol?,
        wallet _: MetaAccountModel,
        selectedChainId _: ChainModel.Id?,
        chainModels _: [ChainModel]?,
        contextTag _: Int?,
        delegate _: SelectNetworkDelegate?
    ) {}

    func showSelectAsset(
        from _: ControllerBackedProtocol?,
        wallet _: MetaAccountModel,
        chainAssets _: [ChainAsset]?,
        selectedAssetId _: AssetModel.Id?,
        output _: SelectAssetModuleOutput
    ) {}

    func showConfirmation(from _: ControllerBackedProtocol?, data: CrossChainConfirmationData) {
        confirmationData = data
    }

    func presentScan(from _: ControllerBackedProtocol?, moduleOutput _: ScanQRModuleOutput) {}

    func presentHistory(
        from _: ControllerBackedProtocol?,
        wallet _: MetaAccountModel,
        chainAsset _: ChainAsset,
        moduleOutput _: ContactsModuleOutput
    ) {}

    func showWalletManagment(
        selectedWalletId _: MetaAccountId?,
        from _: ControllerBackedProtocol?,
        moduleOutput _: WalletsManagmentModuleOutput?
    ) {}

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        messages.append(viewModel.message ?? viewModel.title)
    }

    func present(
        message: String?,
        title: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {
        messages.append(message ?? title)
    }

    func presentInfo(message: String?, title: String, from _: ControllerBackedProtocol?) {
        messages.append(message ?? title)
    }

    func dismiss(view _: ControllerBackedProtocol?) {}
}

// MARK: - Interactor doubles

private final class CrossChainInteractorOutputSpy: CrossChainInteractorOutput {
    var onDestinationExistentialDeposit: (() -> Void)?
    private(set) var destinationExistentialDeposit: Result<BigUInt, Error>?

    func didReceiveAccountInfo(result _: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {}
    func didReceiveAvailableDestChainAssets(_: [ChainAsset]) {}
    func didReceiveDestinationFee(result _: Result<DestXcmFee, Error>) {}
    func didReceiveOriginFee(result _: Result<BigUInt, Error>) {}
    func didReceiveOrigin(chainAssets _: [ChainAsset]) {}
    func didSetup() {}
    func didReceiveExistentialDeposit(result _: Result<BigUInt, Error>) {}
    func didReceiveDestinationAccountInfo(accountInfo _: AccountInfo?) {}
    func didReceiveDestinationAccountInfoError(error _: Error) {}

    func didReceiveDestinationExistentialDeposit(result: Result<BigUInt, Error>) {
        destinationExistentialDeposit = result
        onDestinationExistentialDeposit?()
    }

    func didReceiveAssetAccountInfo(assetAccountInfo _: AssetAccountInfo?) {}
    func didReceiveAssetAccountInfoError(error _: Error) {}
}

private struct ChainAssetFetchingStub: ChainAssetFetchingProtocol {
    let chainAssets: [ChainAsset]

    func fetch(
        shouldUseCache _: Bool,
        filters _: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor],
        completionBlock: @escaping (Result<[ChainAsset], Error>?) -> Void
    ) {
        completionBlock(.success(chainAssets))
    }

    func fetchAwaitOperation(
        shouldUseCache _: Bool,
        filters _: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor]
    ) -> BaseOperation<[ChainAsset]> {
        ClosureOperation { self.chainAssets }
    }

    func fetchAwait(
        shouldUseCache _: Bool,
        filters _: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor]
    ) async throws -> [ChainAsset] {
        chainAssets
    }
}

private final class AccountInfoSubscriptionAdapterStub: AccountInfoSubscriptionAdapterProtocol {
    func subscribe(
        chainAsset _: ChainAsset,
        accountId _: AccountId,
        handler _: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {}

    func subscribe(
        chainsAssets _: [ChainAsset],
        handler _: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {}

    func reset() {}
    func unsubscribe(chainAsset _: ChainAsset) {}
    func update(wallet _: MetaAccountModel) {}
}

private struct OriginFeeEstimatorStub: ReviewedCrossChainOriginFeeEstimating {
    func estimateOriginFee(
        definition _: ReviewedXcmRouteDefinition,
        wallet _: MetaAccountModel,
        amount _: BigUInt
    ) async throws -> BigUInt {
        BigUInt(10_000_000_000)
    }
}

private struct ExistentialDepositServiceStub: ExistentialDepositServiceProtocol {
    func fetchExistentialDeposit(chainAsset _: ChainAsset, completion: @escaping (Result<BigUInt, Error>) -> Void) {
        completion(.success(.zero))
    }
}

private final class EmptyRepository<Model: Identifiable>: DataProviderRepositoryProtocol {
    func fetchOperation(by _: @escaping () throws -> [String], options _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [] }
    }

    func fetchOperation(by _: @escaping () throws -> String, options _: RepositoryFetchOptions) -> BaseOperation<Model?> {
        ClosureOperation { nil }
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [] }
    }

    func fetchOperation(by _: RepositorySliceRequest, options _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        ClosureOperation { [] }
    }

    func saveOperation(
        _: @escaping () throws -> [Model],
        _: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        ClosureOperation {}
    }

    func saveBatchOperation(
        _: @escaping () throws -> [Model],
        _: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        ClosureOperation {}
    }

    func replaceOperation(_: @escaping () throws -> [Model]) -> BaseOperation<Void> {
        ClosureOperation {}
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation { 0 }
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation {}
    }
}

// MARK: - Confirmation doubles

private struct AuthorizerStub: ReviewedCrossChainSubmissionAuthorizing {
    let submission: ReviewedCrossChainAuthorizedSubmission

    func authorize() async throws -> ReviewedCrossChainAuthorizedSubmission {
        submission
    }
}

private final class ScriptedExecutor: ReviewedCrossChainExtrinsicExecuting {
    private let submitError: Error?
    private let outcome: ReviewedCrossChainDispatchOutcome
    private let extrinsicHash: String
    var onSubmit: (() -> Void)?
    private(set) var submitCount = 0

    init(
        submitError: Error? = nil,
        outcome: ReviewedCrossChainDispatchOutcome = .unknown,
        extrinsicHash: String = "0xhash"
    ) {
        self.submitError = submitError
        self.outcome = outcome
        self.extrinsicHash = extrinsicHash
    }

    func estimateFee(_: @escaping ExtrinsicBuilderClosure) async throws -> RuntimeDispatchInfo {
        RuntimeDispatchInfo(feeValue: BigUInt(1))
    }

    func submit(_: @escaping ExtrinsicBuilderClosure) async throws -> ReviewedCrossChainSubmissionReceipt {
        submitCount += 1
        onSubmit?()
        if let submitError {
            throw submitError
        }
        return ReviewedCrossChainSubmissionReceipt(subscriptionId: "subscription", extrinsicHash: extrinsicHash)
    }

    func dispatchOutcome(for _: ReviewedCrossChainSubmissionReceipt) async -> ReviewedCrossChainDispatchOutcome {
        outcome
    }
}

private final class ConfirmationOutputSpy: CrossChainConfirmationInteractorOutput {
    let expectation: XCTestExpectation
    private(set) var result: ReviewedCrossChainSubmissionResult?
    private(set) var error: Error?
    private(set) var unresolvedAttempts: [ReviewedCrossChainSubmissionRecord] = []
    var unresolved: ReviewedCrossChainSubmissionRecord? { unresolvedAttempts.first }

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func didTransfer(result: Result<ReviewedCrossChainSubmissionResult, Error>) {
        switch result {
        case let .success(value):
            self.result = value
        case let .failure(error):
            self.error = error
        }
        expectation.fulfill()
    }

    func didFindUnresolvedSubmission(_ records: [ReviewedCrossChainSubmissionRecord]) {
        unresolvedAttempts = records
        expectation.fulfill()
    }
}

/// A node for the dispatch watcher: it answers the block and its `System.Events` from a fixture and, once the watcher
/// subscribes, reports the scripted extrinsic statuses in order and optionally ends the subscription.
private final class ScriptedWatchEngine: JSONRPCEngine {
    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }

    private let block: LiberlandBlockFixture
    private let statuses: [String]
    private let endsSubscription: Bool

    init(block: LiberlandBlockFixture, statuses: [String], endsSubscription: Bool) {
        self.block = block
        self.statuses = statuses
        self.endsSubscription = endsSubscription
    }

    func callMethod<P: Codable, T: Decodable>(
        _ method: String,
        params _: P?,
        options _: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        let result: Any
        switch method {
        case RPCMethod.getChainBlock:
            let header: [String: Any] = [
                "digest": ["logs": [String]()],
                "extrinsicsRoot": "0x00",
                "number": "0x0",
                "stateRoot": "0x00",
                "parentHash": "0x00"
            ]
            result = ["block": ["header": header, "extrinsics": block.extrinsics], "justification": NSNull()]
        case RPCMethod.getStorage:
            result = block.events
        default:
            closure?(.failure(JSONRPCEngineError.unknownError))
            return 0
        }
        let data = try JSONSerialization.data(withJSONObject: [result])
        closure?(Result { try JSONDecoder().decode([T].self, from: data)[0] })
        return 0
    }

    func subscribe<P: Codable, T: Decodable>(
        _: String,
        params _: P?,
        updateClosure _: @escaping (T) -> Void,
        failureClosure _: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        0
    }

    func addSubscription(_ subscription: JSONRPCSubscribing) {
        let statuses = statuses
        let endsSubscription = endsSubscription
        DispatchQueue.global().async {
            for status in statuses {
                let update = #"{"jsonrpc":"2.0","method":"author_extrinsicUpdate","params":{"subscription":"subscription","result":\#(status)}}"#
                try? subscription.handle(data: Data(update.utf8))
            }
            if endsSubscription {
                subscription.handle(error: JSONRPCEngineError.remoteCancelled, unsubscribed: true)
            }
        }
    }

    func cancelForIdentifier(_: UInt16) {}
    func generateRequestId() -> UInt16 { 1 }
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_: UInt16) throws {}
}

private struct DestinationFeeStub: XcmDestinationFeeFetching {
    func estimateFee(destinationChainId _: String, token _: String) async -> Result<DestXcmFee, Error> {
        .failure(ReviewedCrossChainSubmissionError.destinationFeeUnavailable)
    }
}

/// `chain_getBlockHash`'s parameter as the extrinsic factory writes it: four big-endian bytes.
private func blockNumberHex(_ number: UInt32) -> String {
    String(format: "0x%08x", number)
}

/// A node for the extrinsic factory: nonce 0, a fixed hash for every block it is asked about except block 0, which it
/// answers with SORA's genesis hash, and a subscription for the submitted extrinsic, which it keeps.
private final class ExtrinsicRPCRecorder: JSONRPCEngine {
    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }

    private let lock = NSLock()
    private var blockHashParameters: [String] = []
    private var submittedExtrinsic: Data?

    var blockHashRequests: [String] {
        lock.lock()
        defer { lock.unlock() }
        return blockHashParameters
    }

    var submitted: Data? {
        lock.lock()
        defer { lock.unlock() }
        return submittedExtrinsic
    }

    func callMethod<P: Codable, T: Decodable>(
        _ method: String,
        params: P?,
        options _: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        let parameters = (params as? [String]) ?? []
        let answer: Any
        switch method {
        case RPCMethod.getExtrinsicNonce:
            answer = 0
        case RPCMethod.getBlockHash:
            lock.lock()
            blockHashParameters.append(contentsOf: parameters)
            lock.unlock()
            answer = parameters == [blockNumberHex(0)]
                ? "0x" + ReviewedXcmRouteRegistry.soraChainId
                : "0x" + String(repeating: "11", count: 32)
        case "author_submitAndWatchExtrinsic":
            let extrinsic = try parameters.first.map { try Data(hexStringSSF: $0) }
            lock.lock()
            submittedExtrinsic = extrinsic
            lock.unlock()
            answer = "subscription"
        default:
            closure?(.failure(JSONRPCEngineError.unknownError))
            return 0
        }
        let data = try JSONSerialization.data(withJSONObject: [answer])
        closure?(Result { try JSONDecoder().decode([T].self, from: data)[0] })
        return 0
    }

    func subscribe<P: Codable, T: Decodable>(
        _: String,
        params _: P?,
        updateClosure _: @escaping (T) -> Void,
        failureClosure _: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        0
    }

    func addSubscription(_: JSONRPCSubscribing) {}
    func cancelForIdentifier(_: UInt16) {}
    func generateRequestId() -> UInt16 { 1 }
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_: UInt16) throws {}
}

/// Signs with a fixed test key and keeps every payload it was asked to sign.
private final class PayloadRecordingSigner: SigningWrapperProtocol {
    private(set) var payloads: [Data] = []

    func sign(_ originalData: Data) throws -> IRSignatureProtocol {
        payloads.append(originalData)
        return try DummySigner(cryptoType: .sr25519).sign(originalData)
    }
}

/// A mortal era born at block 100, so the only block hash the factory needs is that block's.
private struct FixedEraOperationFactory: ExtrinsicEraOperationFactoryProtocol {
    func createOperation(
        from _: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<ExtrinsicEraParameters> {
        CompoundOperationWrapper(targetOperation: ClosureOperation {
            ExtrinsicEraParameters(blockNumber: 100, extrinsicEra: .mortal(period: 64, phase: 36))
        })
    }
}

private extension ChainModel {
    func replacingAssets(_ assets: Set<AssetModel>) -> ChainModel {
        let copy = ChainModel(
            rank: rank,
            disabled: disabled,
            chainId: chainId,
            parentId: parentId,
            paraId: paraId,
            name: name,
            xcm: xcm,
            nodes: nodes,
            addressPrefix: addressPrefix,
            types: types,
            icon: icon,
            options: options,
            externalApi: externalApi,
            selectedNode: selectedNode,
            customNodes: customNodes,
            iosMinAppVersion: iosMinAppVersion,
            identityChain: identityChain
        )
        copy.assets = assets
        return copy
    }
}
