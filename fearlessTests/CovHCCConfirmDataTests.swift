import BigInt
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

/// Pure parts of `CrossChainConfirmationData.swift`: error texts, the route validator, the reviewed call layout,
/// the call builder's encodable bridge arguments and the boundary validator.
final class CovHCCConfirmDataTests: XCTestCase {
    func testEverySubmissionAndDispatchErrorExplainsItself() {
        let submissionErrors: [ReviewedCrossChainSubmissionError] = [
            .actionsPaused, .executionAdapterUnavailable, .unreviewedRoute, .selectedWalletChanged, .signerUnavailable,
            .runtimeUnavailable, .wrongNetwork, .runtimeCallUnavailable, .invalidRecipient, .invalidAmount, .belowMinimum,
            .destinationFeeUnavailable, .destinationFeeChanged, .destinationFeeTooHigh, .balanceUnavailable,
            .insufficientAssetBalance, .insufficientFeeBalance
        ]
        let descriptions = submissionErrors.map { $0.errorDescription ?? "" }
        XCTAssertFalse(descriptions.contains(where: \.isEmpty))
        XCTAssertEqual(Set(descriptions).count, submissionErrors.count, "Every refusal names its own reason")
        XCTAssertEqual(
            ReviewedCrossChainSubmissionError.executionAdapterUnavailable.errorDescription,
            ReviewedXcmExecutionAuthority.unavailableReason
        )
        XCTAssertEqual(ReviewedCrossChainSubmissionError.invalidAmount.errorDescription, "Enter a positive cross-chain amount.")

        let dispatchErrors: [ReviewedCrossChainDispatchError] = [
            .extrinsicFailed(extrinsicHash: nil), .submissionInDoubt, .journalUnavailable, .journalUnreadable
        ]
        let dispatchDescriptions = dispatchErrors.map { $0.errorDescription ?? "" }
        XCTAssertFalse(dispatchDescriptions.contains(where: \.isEmpty))
        XCTAssertEqual(Set(dispatchDescriptions).count, dispatchErrors.count)
        XCTAssertTrue(dispatchDescriptions[2].contains("not sent"))
        XCTAssertEqual(
            dispatchDescriptions[3],
            Bundle.main.localizedString(forKey: "cross_chain.dispatch.journal_unreadable", value: nil, table: nil),
            "The unreadable-journal refusal uses its localized text"
        )
    }

    func testValidatorReportsMissingTrustBeforeTheSwitchAndRefusesAnotherRoutesContext() throws {
        let lld = try CovHCCConfirmFixture.route("LLD")
        let llm = try CovHCCConfirmFixture.route("LLM")
        let origin = try CovHCCConfirmFixture.origin(lld)
        let sora = try CovHCCConfirmFixture.sora()
        let context = CovHCCConfirmFixture.context(lld)

        func error(_ body: () throws -> Void) -> ReviewedCrossChainSubmissionError? {
            do {
                try body()
                return nil
            } catch {
                return error as? ReviewedCrossChainSubmissionError
            }
        }

        XCTAssertEqual(error {
            try ReviewedCrossChainSubmissionValidator.validate(
                origin: origin, destination: sora, reviewedRoute: context, mutationsEnabled: false, executionAdapterAvailable: false
            )
        }, .executionAdapterUnavailable)
        XCTAssertEqual(error {
            try ReviewedCrossChainSubmissionValidator.validate(
                origin: origin, destination: sora, reviewedRoute: context, mutationsEnabled: false, executionAdapterAvailable: true
            )
        }, .actionsPaused)
        XCTAssertEqual(error {
            try ReviewedCrossChainSubmissionValidator.validateReviewedRoute(
                origin: origin, destination: sora, reviewedRoute: context, executionAdapterAvailable: false
            )
        }, .executionAdapterUnavailable)
        XCTAssertEqual(error {
            try ReviewedCrossChainSubmissionValidator.validateReviewedRoute(
                origin: origin, destination: sora, reviewedRoute: CovHCCConfirmFixture.context(llm), executionAdapterAvailable: true
            )
        }, .unreviewedRoute)
        XCTAssertNil(error {
            try ReviewedCrossChainSubmissionValidator.validateReviewedRoute(
                origin: origin, destination: sora, reviewedRoute: context, executionAdapterAvailable: true
            )
        })
    }

    func testCallLayoutRefusesDescriptorsWithoutAReviewedLayoutAndEncodesAssetIds() throws {
        let recipient = Data(repeating: 1, count: 32)
        let liberlandBurn = CovHCCConfirmFixture.execution(
            call: .liberlandSoraBridgeAppBurn,
            asset: .liberlandAsset(currencyId: "258"),
            network: .soraMainnet,
            recipient: .sora
        )

        let assetBytes = try ReviewedCrossChainCallLayout.expected(execution: liberlandBurn, destinationAccountId: recipient, amount: 1)
        XCTAssertEqual(Array(assetBytes.prefix(8)), [81, 3, 0x00, 0x01, 0x02, 0x01, 0x00, 0x00])
        XCTAssertEqual(assetBytes.count, 8 + 1 + 32 + 16)

        let refused: [ReviewedCrossChainExecutionDescriptor] = [
            CovHCCConfirmFixture.execution(),
            CovHCCConfirmFixture.execution(
                call: .liberlandSoraBridgeAppBurn, asset: .liberlandAsset(currencyId: "LLM"), network: .soraMainnet, recipient: .sora
            ),
            CovHCCConfirmFixture.execution(call: .liberlandSoraBridgeAppBurn, network: .soraMainnet, recipient: .sora),
            CovHCCConfirmFixture.execution(
                call: .liberlandSoraBridgeAppBurn, asset: .liberlandNativeLLD, network: .soraMainnet, recipient: .sora, callIndex: nil
            )
        ]
        for execution in refused {
            XCTAssertThrowsError(
                try ReviewedCrossChainCallLayout.expected(execution: execution, destinationAccountId: recipient, amount: 1)
            ) { error in
                XCTAssertEqual(error as? ReviewedCrossChainSubmissionError, .runtimeCallUnavailable)
            }
        }
    }

    func testNegotiatorRefusesAProbeWhoseEncodedBytesDisagreeWithTheReviewedLayout() throws {
        let factory = try CovHCCConfirmFixture.coderFactory()
        let lld = try CovHCCConfirmFixture.route("LLD")
        let builder = CovHCCConfirmCallBuilder(encoded: Data([0x51, 0x03]))
        let negotiator = ReviewedCrossChainRuntimeNegotiator(callBuilder: builder)

        XCTAssertThrowsError(try negotiator.negotiate(factory: factory, specVersion: 34, descriptor: lld.execution)) { error in
            XCTAssertEqual(error as? ReviewedCrossChainSubmissionError, .runtimeCallUnavailable)
        }
        XCTAssertEqual(builder.encodedCalls, 1)

        let capability = try ReviewedCrossChainRuntimeNegotiator().negotiate(factory: factory, specVersion: 34, descriptor: lld.execution)
        XCTAssertEqual(capability, CovHCCConfirmFixture.capability())
    }

    func testNegotiatorReadsTheRuntimeSnapshotBeforeTheCoder() async throws {
        let lld = try CovHCCConfirmFixture.route("LLD")
        let negotiator = ReviewedCrossChainRuntimeNegotiator()

        do {
            _ = try await negotiator.negotiate(runtime: CovHCCConfirmRuntime(), descriptor: lld.execution)
            XCTFail("A runtime without a snapshot cannot be negotiated")
        } catch {
            XCTAssertEqual(error as? ReviewedCrossChainSubmissionError, .runtimeUnavailable)
        }

        let runtime = CovHCCConfirmRuntime(snapshot: try CovHCCConfirmFixture.snapshot(), factory: try CovHCCConfirmFixture.coderFactory())
        let capability = try await negotiator.negotiate(runtime: runtime, descriptor: lld.execution)
        XCTAssertEqual(capability.specVersion, 34)
        XCTAssertEqual(capability.moduleName, "SoraBridgeApp")
    }

    func testCallBuilderEncodesEveryReviewedRecipientShapeAndRefusesTheRest() throws {
        let callBuilder = ReviewedCrossChainCallBuilder()
        let accountId = Data(repeating: 9, count: 32)

        guard case let .liberland(liberlandId) = try callBuilder.makeSoraRecipient(.liberland, accountId: accountId) else {
            return XCTFail("A Liberland recipient stays a Liberland account")
        }
        XCTAssertEqual(liberlandId, accountId)
        XCTAssertThrowsError(try callBuilder.makeSoraRecipient(.sora, accountId: accountId)) { error in
            XCTAssertEqual(error as? ReviewedCrossChainSubmissionError, .unreviewedRoute)
        }

        let relay = try callBuilder.makeSoraRecipient(.relay(accountNetwork: .polkadot), accountId: accountId)
        let parachain = try callBuilder.makeSoraRecipient(.parachain(paraId: 2011, accountNetwork: .kusama), accountId: accountId)
        let relayJSON = try String(decoding: JSONEncoder().encode(relay), as: UTF8.self)
        let parachainJSON = try String(decoding: JSONEncoder().encode(parachain), as: UTF8.self)
        XCTAssertTrue(relayJSON.hasPrefix("[\"Parachain\",[\"V3\""), relayJSON)
        XCTAssertTrue(relayJSON.contains("\"X1\""), relayJSON)
        XCTAssertTrue(relayJSON.contains("Polkadot"), relayJSON)
        XCTAssertTrue(parachainJSON.contains("\"X2\""), parachainJSON)
        XCTAssertTrue(parachainJSON.contains("2011"), parachainJSON)
        XCTAssertTrue(parachainJSON.contains("Kusama"), parachainJSON)

        let lld = try CovHCCConfirmFixture.route("LLD")
        let capability = CovHCCConfirmFixture.capability()
        let proxyShapes: [(ReviewedCrossChainSubNetwork, ReviewedCrossChainRecipientDescriptor)] = [
            (.soraMainnet, .liberland),
            (.kusama, .relay(accountNetwork: .kusama)),
            (.polkadot, .parachain(paraId: 2000, accountNetwork: .polkadot)),
            (.liberland, .liberland)
        ]
        for (network, recipient) in proxyShapes {
            let definition = CovHCCConfirmFixture.definition(
                from: lld,
                execution: CovHCCConfirmFixture.execution(network: network, recipient: recipient)
            )
            XCTAssertNoThrow(
                try callBuilder.builder(definition: definition, capability: capability, destinationAccountId: accountId, amount: 5),
                "\(network)"
            )
        }

        let refusals: [(ReviewedCrossChainExecutionDescriptor, Data, BigUInt, ReviewedCrossChainSubmissionError)] = [
            (CovHCCConfirmFixture.execution(), Data(repeating: 9, count: 20), 5, .invalidRecipient),
            (CovHCCConfirmFixture.execution(), accountId, 0, .invalidAmount),
            (CovHCCConfirmFixture.execution(), accountId, ReviewedCrossChainCallLayout.maximumAmount + 1, .invalidAmount),
            (CovHCCConfirmFixture.execution(asset: .liberlandNativeLLD), accountId, 5, .unreviewedRoute),
            (CovHCCConfirmFixture.execution(recipient: .sora), accountId, 5, .unreviewedRoute),
            (CovHCCConfirmFixture.execution(call: .liberlandSoraBridgeAppBurn, network: .kusama, recipient: .sora), accountId, 5, .unreviewedRoute),
            (CovHCCConfirmFixture.execution(call: .liberlandSoraBridgeAppBurn, network: .soraMainnet, recipient: .sora), accountId, 5, .unreviewedRoute)
        ]
        for (execution, recipient, amount, expected) in refusals {
            let definition = CovHCCConfirmFixture.definition(from: lld, execution: execution)
            XCTAssertThrowsError(
                try callBuilder.builder(definition: definition, capability: capability, destinationAccountId: recipient, amount: amount)
            ) { error in
                XCTAssertEqual(error as? ReviewedCrossChainSubmissionError, expected, "\(execution.fingerprint)")
            }
        }
    }

    func testBridgeArgumentsAreEncodeOnly() throws {
        let decoder = JSONDecoder()
        let payload = Data("[\"Any\",null]".utf8)
        let attempts: [() throws -> Void] = [
            { _ = try decoder.decode(ReviewedBridgeJunctionNetworkId.self, from: payload) },
            { _ = try decoder.decode(ReviewedBridgeJunction.self, from: payload) },
            { _ = try decoder.decode(ReviewedBridgeJunctions.self, from: payload) },
            { _ = try decoder.decode(ReviewedBridgeVersionedMultiLocation.self, from: payload) },
            { _ = try decoder.decode(ReviewedBridgeGenericAccount.self, from: payload) }
        ]
        for attempt in attempts {
            XCTAssertThrowsError(try attempt()) { error in
                guard case DecodingError.dataCorrupted = error else {
                    return XCTFail("Expected an encode-only refusal, got \(error)")
                }
            }
        }

        let encoder = JSONEncoder()
        XCTAssertEqual(String(decoding: try encoder.encode(ReviewedBridgeJunctions(items: [])), as: UTF8.self), "[\"Here\",null]")
        XCTAssertEqual(String(decoding: try encoder.encode(ReviewedBridgeJunctionNetworkId.any), as: UTF8.self), "[\"Any\",null]")
        XCTAssertEqual(String(decoding: try encoder.encode(ReviewedBridgeJunctionNetworkId(.liberland)), as: UTF8.self), "[\"Any\",null]")
        XCTAssertEqual(String(decoding: try encoder.encode(ReviewedBridgeJunctionNetworkId(.kusama)), as: UTF8.self), "[\"Kusama\",null]")
        let soraAccount = String(decoding: try encoder.encode(ReviewedBridgeGenericAccount.sora(Data(repeating: 1, count: 32))), as: UTF8.self)
        XCTAssertTrue(soraAccount.hasPrefix("[\"Sora\""), soraAccount)
    }

    func testBoundaryValidatorChecksFeeAmountMinimumAndBothBalances() throws {
        let lld = try CovHCCConfirmFixture.route("LLD")
        XCTAssertThrowsError(
            try ReviewedCrossChainSubmissionBoundaryValidator.requireConfirmedDestinationFee(fresh: 5, confirmed: 1, originPrecision: 12)
        ) { error in
            XCTAssertEqual(error as? ReviewedCrossChainSubmissionError, .destinationFeeChanged)
        }
        XCTAssertNoThrow(
            try ReviewedCrossChainSubmissionBoundaryValidator.requireConfirmedDestinationFee(
                fresh: 5_000_000_000_000, confirmed: 5, originPrecision: 12
            )
        )

        var execution = lld.execution
        execution = ReviewedCrossChainExecutionDescriptor(
            runtimeCall: execution.runtimeCall,
            asset: .liberlandNativeLLD,
            destinationChainId: execution.destinationChainId,
            network: execution.network,
            recipient: execution.recipient,
            minimumAmount: "100",
            callIndex: execution.callIndex
        )
        let definition = CovHCCConfirmFixture.definition(from: lld, execution: execution)
        let originKey = AssetKey(ecosystem: "substrate", chainId: lld.originChainId, assetId: lld.originAssetId)
        let feeKey = AssetKey(ecosystem: "substrate", chainId: lld.originChainId, assetId: "fee-asset")

        func refusal(
            requested: BigUInt = 1000,
            burn: BigUInt = 1000,
            fee: BigUInt = 10,
            origin: AssetKey? = nil,
            feeAsset: AssetKey? = nil,
            originSpendable: BigUInt? = 10000,
            feeSpendable: BigUInt? = 10000
        ) -> ReviewedCrossChainSubmissionError? {
            let balances = ReviewedCrossChainAuthoritativeBalances(
                originAssetKey: origin ?? originKey,
                feeAssetKey: feeAsset ?? originKey,
                originSpendable: originSpendable,
                feeSpendable: feeSpendable
            )
            do {
                try ReviewedCrossChainSubmissionBoundaryValidator.validate(
                    definition: definition, requestedAmount: requested, burnAmount: burn, balances: balances, originFee: fee
                )
                return nil
            } catch {
                return error as? ReviewedCrossChainSubmissionError
            }
        }

        XCTAssertEqual(refusal(requested: 0, burn: 0), .invalidAmount)
        XCTAssertEqual(refusal(burn: 999), .invalidAmount)
        XCTAssertEqual(refusal(fee: 0), .invalidAmount)
        XCTAssertEqual(refusal(requested: 50, burn: 50), .belowMinimum)
        XCTAssertEqual(refusal(origin: feeKey), .balanceUnavailable)
        XCTAssertEqual(refusal(originSpendable: nil), .balanceUnavailable)
        XCTAssertEqual(refusal(feeSpendable: nil), .balanceUnavailable)
        XCTAssertEqual(refusal(originSpendable: 1005), .insufficientAssetBalance)
        XCTAssertNil(refusal(originSpendable: 1010))
        XCTAssertEqual(refusal(feeAsset: feeKey, originSpendable: 999), .insufficientAssetBalance)
        XCTAssertEqual(refusal(feeAsset: feeKey, originSpendable: 1000, feeSpendable: 9), .insufficientFeeBalance)
        XCTAssertNil(refusal(feeAsset: feeKey, originSpendable: 1000, feeSpendable: 10))
    }

    func testGenesisReaderReturnsTheNodesBlockZeroHashOrItsFailure() async throws {
        let engine = CovHCCConfirmEngine()
        engine.genesisHash = "0x" + CovHCCConfirmFixture.liberlandId
        let hash = try await ReviewedCrossChainGenesisReader().genesisHash(connection: engine)
        XCTAssertEqual(hash, "0x" + CovHCCConfirmFixture.liberlandId)
        XCTAssertEqual(engine.methods, [RPCMethod.getBlockHash])

        let silent = CovHCCConfirmEngine()
        do {
            _ = try await ReviewedCrossChainGenesisReader().genesisHash(connection: silent)
            XCTFail("A failed answer must not become a hash")
        } catch {
            XCTAssertNotNil(error as? JSONRPCEngineError)
        }

        let broken = CovHCCConfirmEngine()
        broken.throwsOnCall = true
        do {
            _ = try await ReviewedCrossChainGenesisReader().genesisHash(connection: broken)
            XCTFail("A request that cannot be sent must fail")
        } catch {
            XCTAssertEqual(error as? CovHCCConfirmError, .stub)
        }
    }
}

final class CovHCCConfirmCallBuilder: ReviewedCrossChainCallBuilding {
    let encoded: Data
    private(set) var encodedCalls = 0

    init(encoded: Data) {
        self.encoded = encoded
    }

    func builder(
        definition _: ReviewedXcmRouteDefinition,
        capability _: ReviewedCrossChainRuntimeCapability,
        destinationAccountId _: AccountId,
        amount _: BigUInt
    ) throws -> ExtrinsicBuilderClosure {
        { $0 }
    }

    func encodedCall(
        execution _: ReviewedCrossChainExecutionDescriptor,
        capability _: ReviewedCrossChainRuntimeCapability,
        destinationAccountId _: AccountId,
        amount _: BigUInt,
        factory _: RuntimeCoderFactoryProtocol
    ) throws -> Data {
        encodedCalls += 1
        return encoded
    }
}
