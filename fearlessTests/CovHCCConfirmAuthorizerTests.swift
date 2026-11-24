import BigInt
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

/// The submission authorizer's refusals in order, the executor, the balance provider and the origin fee estimator.
final class CovHCCConfirmAuthorizerTests: XCTestCase {
    private struct Harness {
        let wallet: MetaAccountModel
        let registry: CovHCCConfirmRegistry
        let keystore: CovHCCConfirmKeystore
        let engine: CovHCCConfirmEngine
        let definition: ReviewedXcmRouteDefinition
    }

    private func harness(withChains: Bool = true, hasKey: Bool = true) throws -> Harness {
        let chains = withChains ? [try CovHCCConfirmFixture.liberland(), try CovHCCConfirmFixture.sora()] : []
        let engine = CovHCCConfirmEngine()
        let registry = CovHCCConfirmRegistry(chains: chains)
        registry.connection = engine
        return Harness(
            wallet: AccountGenerator.generateMetaAccount(),
            registry: registry,
            keystore: CovHCCConfirmKeystore(hasKey: hasKey),
            engine: engine,
            definition: try CovHCCConfirmFixture.route("LLD")
        )
    }

    private func recipient() throws -> String {
        try Data(repeating: 7, count: 32).toAddress(using: CovHCCConfirmFixture.sora().chainFormat as ChainFormat)
    }

    private func authorizer(
        _ harness: Harness,
        recipient: String = "recipient",
        destinationFee: Decimal = .zero,
        selectedWallet: MetaAccountModel?? = nil,
        mutationsEnabled: Bool = true,
        executionAvailable: Bool = true,
        genesis: Result<String, Error> = .success("0x" + CovHCCConfirmFixture.liberlandId),
        negotiator: ReviewedCrossChainRuntimeNegotiating = ReviewedCrossChainRuntimeNegotiator()
    ) throws -> ReviewedCrossChainSubmissionAuthorizer {
        let data = try CovHCCConfirmFixture.confirmationData(
            wallet: harness.wallet,
            recipient: recipient,
            destinationFee: destinationFee
        )
        let selected: MetaAccountModel? = selectedWallet ?? harness.wallet
        return ReviewedCrossChainSubmissionAuthorizer(
            data: data,
            runtimeNegotiator: negotiator,
            genesisReader: CovHCCConfirmGenesisReader(result: genesis),
            chainRegistry: harness.registry,
            keystore: harness.keystore,
            selectedWallet: { selected },
            mutationsEnabled: { mutationsEnabled },
            executionAvailable: executionAvailable
        )
    }

    private func refusal(_ authorizer: ReviewedCrossChainSubmissionAuthorizer) -> Error? {
        CovHCCConfirmAsyncBox { try await authorizer.authorize() }.error
    }

    private func appRuntime() throws -> fearless.RuntimeProvider {
        let liberland = try CovHCCConfirmFixture.liberland()
        let provider = fearless.RuntimeProvider(
            chainModel: liberland,
            snapshotOperationFactory: CovHCCConfirmSnapshotFactory(snapshot: try CovHCCConfirmFixture.snapshot()),
            snapshotHotOperationFactory: nil,
            eventCenter: EventCenter(),
            operationQueue: OperationQueue(),
            repository: AnyDataProviderRepository(CovHCCConfirmEmptyRepository<fearless.RuntimeMetadataItem>()),
            usedRuntimePaths: [:],
            chainMetadata: fearless.RuntimeMetadataItem(chain: liberland.chainId, version: 34, txVersion: 2, metadata: Data()),
            chainTypes: Data()
        )
        provider.setup()
        CovHCCConfirmFixture.spin(timeout: 10) { provider.mutationAuthorizationSpecVersion != nil }
        XCTAssertEqual(provider.mutationAuthorizationSpecVersion, 34)
        return provider
    }

    func testPolicyAndWalletAreCheckedBeforeAnyChainIsRead() throws {
        let fixture = try harness()
        let other = AccountGenerator.generateMetaAccount()

        XCTAssertEqual(
            refusal(try authorizer(fixture, executionAvailable: false)) as? ReviewedCrossChainSubmissionError,
            .executionAdapterUnavailable
        )
        XCTAssertEqual(
            refusal(try authorizer(fixture, mutationsEnabled: false)) as? ReviewedCrossChainSubmissionError,
            .actionsPaused
        )
        XCTAssertEqual(
            refusal(try authorizer(fixture, selectedWallet: .some(other))) as? ReviewedCrossChainSubmissionError,
            .selectedWalletChanged
        )
        XCTAssertEqual(
            refusal(try authorizer(fixture, selectedWallet: .some(nil))) as? ReviewedCrossChainSubmissionError,
            .selectedWalletChanged
        )
        XCTAssertTrue(fixture.keystore.checkedTags.isEmpty)
        XCTAssertTrue(fixture.engine.methods.isEmpty)
    }

    func testRouteSignerAndRecipientAreRequiredBeforeTheRuntime() throws {
        let noChains = try harness(withChains: false)
        XCTAssertEqual(refusal(try authorizer(noChains)) as? ReviewedCrossChainSubmissionError, .unreviewedRoute)

        let noKey = try harness(hasKey: false)
        XCTAssertEqual(refusal(try authorizer(noKey)) as? ReviewedCrossChainSubmissionError, .signerUnavailable)
        XCTAssertEqual(noKey.keystore.checkedTags.count, 1)

        let unreadableKey = try harness()
        unreadableKey.keystore.throwsOnCheck = true
        XCTAssertEqual(refusal(try authorizer(unreadableKey)) as? ReviewedCrossChainSubmissionError, .signerUnavailable)

        let fixture = try harness()
        XCTAssertEqual(refusal(try authorizer(fixture, recipient: "recipient")) as? ReviewedCrossChainSubmissionError, .invalidRecipient)
        let systemAccount = try Data(repeating: 0, count: 32).toAddress(using: CovHCCConfirmFixture.sora().chainFormat as ChainFormat)
        XCTAssertEqual(refusal(try authorizer(fixture, recipient: systemAccount)) as? ReviewedCrossChainSubmissionError, .invalidRecipient)

        XCTAssertEqual(refusal(try authorizer(fixture, recipient: try recipient())) as? ReviewedCrossChainSubmissionError, .runtimeUnavailable)
        fixture.registry.runtime = CovHCCConfirmRuntime()
        XCTAssertEqual(
            refusal(try authorizer(fixture, recipient: try recipient())) as? ReviewedCrossChainSubmissionError,
            .runtimeUnavailable,
            "A runtime without a snapshot is unavailable"
        )
    }

    func testANodeOfAnotherNetworkIsRefusedAndAnUnqualifiedRuntimeCannotAuthorize() throws {
        let fixture = try harness()
        fixture.registry.runtime = CovHCCConfirmRuntime(
            snapshot: try CovHCCConfirmFixture.snapshot(),
            factory: try CovHCCConfirmFixture.coderFactory()
        )
        let address = try recipient()

        XCTAssertEqual(
            refusal(try authorizer(fixture, recipient: address, genesis: .success("0x" + CovHCCConfirmFixture.soraId)))
                as? ReviewedCrossChainSubmissionError,
            .wrongNetwork
        )
        XCTAssertEqual(
            refusal(try authorizer(fixture, recipient: address, genesis: .failure(CovHCCConfirmError.stub))) as? CovHCCConfirmError,
            .stub
        )
        // Only the app's own runtime provider can answer the spec version at the signing boundary.
        XCTAssertEqual(refusal(try authorizer(fixture, recipient: address)) as? ReviewedCrossChainSubmissionError, .runtimeUnavailable)
        XCTAssertEqual(fixture.keystore.checkedTags.count, 3)
    }

    func testFreshRoundsCheckSpecVersionDestinationFeeAndThenAskTheNodeForTheFee() throws {
        let fixture = try harness()
        fixture.registry.runtime = try appRuntime()
        let address = try recipient()
        let destinationPlanks = try ReviewedXcmRouteRegistry.destinationFee(for: fixture.definition)
        let destinationFee = try XCTUnwrap(
            Decimal.fromSubstrateAmount(destinationPlanks, precision: Int16(fixture.definition.originPrecision))
        )

        let stale = CovHCCConfirmNegotiator(result: .success(CovHCCConfirmFixture.capability(specVersion: 33)))
        XCTAssertEqual(
            refusal(try authorizer(fixture, recipient: address, destinationFee: destinationFee, negotiator: stale))
                as? ReviewedCrossChainSubmissionError,
            .runtimeUnavailable
        )
        XCTAssertEqual(
            refusal(try authorizer(fixture, recipient: address, destinationFee: destinationFee + 1)) as? ReviewedCrossChainSubmissionError,
            .destinationFeeChanged
        )
        XCTAssertTrue(fixture.engine.methods.isEmpty, "Nothing reaches the node before the call and fee are confirmed")

        let error = refusal(try authorizer(fixture, recipient: address, destinationFee: destinationFee))
        XCTAssertNotNil(error, "The scripted node answers no fee query")
        XCTAssertNil(error as? ReviewedCrossChainSubmissionError)
        XCTAssertFalse(fixture.engine.methods.isEmpty, "The exact reviewed call reached fee estimation")
    }

    func testExecutorEstimatesSubmitsOnlyWithAuthorizationAndReadsTheOutcome() async throws {
        let service = CovHCCConfirmExtrinsicService()
        let fee = try await ReviewedCrossChainExtrinsicExecutor(service: service).estimateFee { $0 }
        XCTAssertEqual(fee.fee, "7")

        service.feeResult = .failure(CovHCCConfirmError.stub)
        do {
            _ = try await ReviewedCrossChainExtrinsicExecutor(service: service).estimateFee { $0 }
            XCTFail("A failed estimate must throw")
        } catch {
            XCTAssertEqual(error as? CovHCCConfirmError, .stub)
        }

        for signer in [nil, CovHCCConfirmSigner(authorization: nil)] {
            do {
                _ = try await ReviewedCrossChainExtrinsicExecutor(service: service, signer: signer).submit { $0 }
                XCTFail("Submitting needs a mutation authorization")
            } catch {
                XCTAssertEqual(error as? MutationAuthorizationError, .denied)
            }
        }
        XCTAssertEqual(service.submitAndWatchCount, 0)

        let authorization = try MutationOperationAuthorization(
            intentSha256: String(repeating: "a", count: 64),
            validateContext: {},
            boundary: { try $0() }
        )
        let executor = ReviewedCrossChainExtrinsicExecutor(
            service: service,
            signer: CovHCCConfirmSigner(authorization: authorization),
            dispatchWatcher: CovHCCConfirmWatcher(result: .succeeded(blockHash: "0xblock"))
        )
        let receipt = try await executor.submit { $0 }
        XCTAssertEqual(receipt.subscriptionId, "subscription")
        let hash = try XCTUnwrap(receipt.extrinsicHash)
        XCTAssertTrue(hash.hasPrefix("0x"))
        XCTAssertEqual(hash.count, 66)
        let outcome = await executor.dispatchOutcome(for: receipt)
        XCTAssertEqual(outcome, .succeeded(blockHash: "0xblock"))
        let withoutHash = await executor.dispatchOutcome(for: ReviewedCrossChainSubmissionReceipt(subscriptionId: "s", extrinsicHash: nil))
        XCTAssertEqual(withoutHash, .unknown)
        let unwatched = await ReviewedCrossChainExtrinsicExecutor(service: service).dispatchOutcome(for: receipt)
        XCTAssertEqual(unwatched, .unknown)

        service.extrinsicHex = nil
        let noHex = try await executor.submit { $0 }
        XCTAssertNil(noHex.extrinsicHash)

        service.submitResult = .failure(CovHCCConfirmError.stub)
        do {
            _ = try await executor.submit { $0 }
            XCTFail("A refused submission must throw")
        } catch {
            XCTAssertEqual(error as? CovHCCConfirmError, .stub)
        }
        XCTAssertEqual(service.submitAndWatchCount, 3)
    }

    func testBalanceProviderReadsExactlyTheOriginAndFeeAssets() async throws {
        let liberland = try CovHCCConfirmFixture.liberland()
        let wallet = AccountGenerator.generateMetaAccount()
        let llm = try CovHCCConfirmFixture.route("LLM")
        let origin = try CovHCCConfirmFixture.origin(llm)
        let utility = try XCTUnwrap(liberland.chainAssets.first(where: \.isUtility))
        let service = CovHCCConfirmAccountInfoService()
        service.infos = [
            origin.chainAssetId: AccountInfo(ethBalance: 500),
            utility.chainAssetId: AccountInfo(ethBalance: 70)
        ]
        let provider = ReviewedCrossChainBalanceProvider(
            wallet: wallet,
            chain: liberland,
            definition: llm,
            accountInfoRemoteService: service
        )

        let balances = await provider.balances()
        XCTAssertEqual(balances.originAssetKey, origin.assetKey)
        XCTAssertEqual(balances.feeAssetKey, utility.assetKey)
        XCTAssertEqual(balances.originSpendable, AccountInfo(ethBalance: 500).data.sendAvailable)
        XCTAssertEqual(balances.feeSpendable, AccountInfo(ethBalance: 70).data.sendAvailable)

        service.error = CovHCCConfirmError.stub
        let failed = await provider.balances()
        XCTAssertEqual(failed.originAssetKey, origin.assetKey)
        XCTAssertNil(failed.originSpendable)
        XCTAssertNil(failed.feeSpendable)
        XCTAssertEqual(service.requests, 2)

        // The SORA catalog has no Liberland LLD row: nothing is read and nothing is spendable.
        let defaultProvider = ReviewedCrossChainBalanceProvider(
            wallet: wallet,
            chain: try CovHCCConfirmFixture.sora(),
            definition: try CovHCCConfirmFixture.route("LLD")
        )
        let missing = await defaultProvider.balances()
        XCTAssertNil(missing.originAssetKey)
        XCTAssertNil(missing.originSpendable)
        XCTAssertNil(missing.feeSpendable)
    }

    func testOriginFeeEstimatorNeedsTheChainAccountRuntimeAndConnection() throws {
        let definition = try CovHCCConfirmFixture.route("LLD")
        let wallet = AccountGenerator.generateMetaAccount()
        let registry = CovHCCConfirmRegistry(chains: [try CovHCCConfirmFixture.liberland()])

        let unavailable = ReviewedCrossChainOriginFeeEstimator(chainRegistry: registry)
        XCTAssertEqual(
            CovHCCConfirmAsyncBox { try await unavailable.estimateOriginFee(definition: definition, wallet: wallet, amount: 1) }.error
                as? ReviewedCrossChainSubmissionError,
            .runtimeUnavailable
        )

        let engine = CovHCCConfirmEngine()
        registry.connection = engine
        registry.runtime = CovHCCConfirmRuntime()
        let refusingNegotiator = ReviewedCrossChainOriginFeeEstimator(
            chainRegistry: registry,
            runtimeNegotiator: CovHCCConfirmNegotiator(result: .failure(ReviewedCrossChainSubmissionError.runtimeCallUnavailable))
        )
        XCTAssertEqual(
            CovHCCConfirmAsyncBox { try await refusingNegotiator.estimateOriginFee(definition: definition, wallet: wallet, amount: 0) }.error
                as? ReviewedCrossChainSubmissionError,
            .runtimeCallUnavailable
        )

        let estimator = ReviewedCrossChainOriginFeeEstimator(
            chainRegistry: registry,
            runtimeNegotiator: CovHCCConfirmNegotiator(result: .success(CovHCCConfirmFixture.capability())),
            operationManager: OperationManager()
        )
        let box = CovHCCConfirmAsyncBox { try await estimator.estimateOriginFee(definition: definition, wallet: wallet, amount: 0) }
        XCTAssertNotNil(box.error, "A runtime without a coder cannot estimate a fee")
        XCTAssertNil(box.value)
    }
}

final class CovHCCConfirmEmptyRepository<Model: Identifiable>: DataProviderRepositoryProtocol {
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

    func saveOperation(_: @escaping () throws -> [Model], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation {}
    }

    func saveBatchOperation(_: @escaping () throws -> [Model], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
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
