import BigInt
import Foundation
import RobinHood
import SoraKeystore
import SSFChainConnection
import SSFChainRegistry
import SSFModels
import SSFPools
import SSFRuntimeCodingService
import SSFUtils
import XCTest

@testable import fearless

/// App and package registry in one object, as `ChainRegistryFacade.sharedRegistry` is. Package storage reads fail at once.
final class CovDDualRegistry: ChainRegistryProtocolStub, SSFChainRegistry.ChainRegistryProtocol, @unchecked Sendable {
    var chains: [SSFModels.ChainModel.Id: SSFModels.ChainModel] = [:]
    var runtime: SSFRuntimeCodingService.RuntimeProviderProtocol?
    var connection: fearless.ChainConnection?
    private(set) var substrateConnectionRequests = 0

    override var availableChains: [SSFModels.ChainModel] { Array(chains.values) }

    override func getChain(for chainId: SSFModels.ChainModel.Id) -> SSFModels.ChainModel? { chains[chainId] }

    override func getRuntimeProvider(for _: SSFModels.ChainModel.Id) -> SSFRuntimeCodingService.RuntimeProviderProtocol? {
        runtime
    }

    override func getConnection(for _: SSFModels.ChainModel.Id) -> fearless.ChainConnection? { connection }

    func getRuntimeProvider(
        chainId _: SSFModels.ChainModel.Id,
        usedRuntimePaths _: [String: [String]],
        runtimeItem _: RuntimeMetadataItemProtocol?
    ) async throws -> SSFRuntimeCodingService.RuntimeProviderProtocol {
        guard let runtime else { throw CovDTestError.offline }
        return runtime
    }

    func getSubstrateConnection(for _: SSFModels.ChainModel) throws -> SubstrateConnection {
        substrateConnectionRequests += 1
        throw CovDTestError.offline
    }

    func getEthereumConnection(for _: SSFModels.ChainModel) throws -> Web3EthConnection {
        throw CovDTestError.offline
    }

    func getChain(for chainId: SSFModels.ChainModel.Id) async throws -> SSFModels.ChainModel {
        guard let chain = chains[chainId] else { throw CovDTestError.offline }
        return chain
    }

    func getChains() async throws -> [SSFModels.ChainModel] { Array(chains.values) }

    func getReadySnapshot(
        chainId _: SSFModels.ChainModel.Id,
        usedRuntimePaths _: [String: [String]],
        runtimeItem _: RuntimeMetadataItemProtocol?
    ) async throws -> RuntimeSnapshot {
        throw CovDTestError.offline
    }
}

/// Runtime whose V1 metadata declares SORA's TradingPair and PoolXYK pallets with the given call names.
final class CovDPoolRuntime: SSFRuntimeCodingService.RuntimeProviderProtocol {
    var runtimeSpecVersion: RuntimeSpecVersion = .defaultVersion
    let snapshot: RuntimeSnapshot?
    private let factory: RuntimeCoderFactoryProtocol

    init(
        poolCalls: [String] = ["deposit_liquidity", "withdraw_liquidity", "initialize_pool"],
        pairCalls: [String] = ["register"]
    ) throws {
        func module(_ name: String, calls: [String], index: UInt8) -> RuntimeMetadataV1.ModuleMetadata {
            RuntimeMetadataV1.ModuleMetadata(
                name: name, storage: nil,
                calls: calls.map { RuntimeMetadataV1.FunctionMetadata(name: $0, arguments: [], documentation: []) },
                events: nil, constants: [], errors: [], index: index
            )
        }
        let metadata = try RuntimeMetadata.v1(
            modules: [module("TradingPair", calls: pairCalls, index: 1), module("PoolXYK", calls: poolCalls, index: 2)],
            extrinsic: .init(version: 4, signedExtensions: [])
        )
        let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
            Data(#"{"types":{}}"#.utf8), runtimeMetadata: metadata, usedRuntimePaths: [:]
        )
        factory = TestRuntimeCoderFactory(catalog: catalog, specVersion: 7, txVersion: 1, metadata: metadata)
        snapshot = RuntimeSnapshot(typeRegistryCatalog: catalog, specVersion: 7, txVersion: 1, metadata: metadata)
    }

    func setup() {}
    func setupHot() {}
    func cleanup() {}
    func readySnapshot() async throws -> RuntimeSnapshot { try XCTUnwrap(snapshot) }
    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol { factory }
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> { ClosureOperation { self.factory } }
}

final class CovDReviewedPoolServiceTests: XCTestCase {
    private struct CovDPoolScenario {
        let chain: ChainModel
        let wallet: MetaAccountModel
        let registry: CovDDualRegistry
        let keystore: InMemoryKeychain
    }

    private func scenario(signing: Bool = true, runtime: CovDPoolRuntime? = nil) throws -> CovDPoolScenario {
        let chain = CovDLiquidityFixtures.chain(chainId: PolkamarktConstants.soraChainId)
        let wallet = CovDFixtures.wallet()
        let registry = CovDDualRegistry()
        registry.chains[chain.chainId] = chain
        registry.runtime = try runtime ?? CovDPoolRuntime()
        registry.connection = MockConnection()
        let keystore = InMemoryKeychain()
        if signing {
            try keystore.addKey(Data(repeating: 5, count: 32), with: chain.keystoreTag(metaId: wallet.metaId))
        }
        return CovDPoolScenario(chain: chain, wallet: wallet, registry: registry, keystore: keystore)
    }

    private func makeService(
        _ scenario: CovDPoolScenario,
        selected: @escaping () -> MetaAccountModel? = { nil },
        enabled: @escaping () -> Bool = { true },
        accepted: @escaping () -> Bool = { true }
    ) throws -> ReviewedPolkaswapPoolsOperationService {
        let wallet = scenario.wallet
        return try XCTUnwrap(ReviewedPolkaswapPoolsOperationService(
            chain: scenario.chain,
            wallet: wallet,
            chainRegistry: scenario.registry,
            keystore: scenario.keystore,
            selectedWallet: { selected() ?? wallet },
            mutationsEnabled: enabled,
            disclaimerAccepted: accepted
        ))
    }

    private func supply(
        dexId: String = "0",
        target: String = CovDLiquidityFixtures.val,
        targetPrecision: Int16 = 18,
        amount: Decimal = 1,
        slippage: Decimal = 0.5
    ) -> PoolOperation {
        .substrateSupplyLiquidity(SupplyLiquidityInfo(
            dexId: dexId,
            baseAsset: PooledAssetInfo(id: CovDLiquidityFixtures.xor, precision: 18),
            targetAsset: PooledAssetInfo(id: target, precision: targetPrecision),
            baseAssetAmount: amount,
            targetAssetAmount: 2,
            slippage: slippage
        ))
    }

    private func removal(amount: Decimal = 1) -> PoolOperation {
        .substrateRemoveLiquidity(RemoveLiquidityInfo(
            dexId: "0",
            baseAsset: PooledAssetInfo(id: CovDLiquidityFixtures.xor, precision: 18),
            targetAsset: PooledAssetInfo(id: CovDLiquidityFixtures.val, precision: 18),
            baseAssetAmount: amount,
            targetAssetAmount: 2,
            baseAssetReserves: 100,
            totalIssuances: 500,
            slippage: 0.5
        ))
    }

    private func feeError(_ service: ReviewedPolkaswapPoolsOperationService, _ operation: PoolOperation) async -> Error? {
        do {
            _ = try await service.estimateFee(liquidityOperation: operation)
            return nil
        } catch {
            return error
        }
    }

    private func submitError(_ service: ReviewedPolkaswapPoolsOperationService, _ operation: PoolOperation) async -> Error? {
        do {
            _ = try await service.submit(liquidityOperation: operation)
            return nil
        } catch {
            return error
        }
    }

    func testErrorsExplainEveryRefusalAndOnlySoraMainnetIsAccepted() throws {
        let all: [ReviewedPolkaswapPoolSubmissionError] = [
            .actionsPaused, .disclaimerRequired, .selectedWalletChanged, .runtimeUnavailable, .signerUnavailable,
            .runtimeCallUnavailable, .invalidPair, .invalidAmount, .poolUnavailable, .positionUnavailable,
            .insufficientPosition, .balanceUnavailable, .insufficientAsset, .insufficientFee
        ]
        let descriptions = all.compactMap(\.errorDescription)
        XCTAssertEqual(Set(descriptions).count, all.count)
        XCTAssertEqual(
            ReviewedPolkaswapPoolSubmissionError.disclaimerRequired.errorDescription,
            "Read and accept the current Polkaswap disclaimer before changing SORA liquidity."
        )
        XCTAssertTrue(descriptions.allSatisfy { $0.hasSuffix(".") })

        let other = try scenario()
        XCTAssertNil(ReviewedPolkaswapPoolsOperationService(
            chain: CovDLiquidityFixtures.chain(), wallet: other.wallet, chainRegistry: other.registry
        ))
        XCTAssertNotNil(ReviewedPolkaswapPoolsOperationService(
            chain: other.chain, wallet: other.wallet, chainRegistry: other.registry
        ))
    }

    func testSubmissionChecksKillSwitchDisclaimerAndWalletFirst() async throws {
        let fixture = try scenario()
        let paused = try await submitError(makeService(fixture, enabled: { false }), supply())
        XCTAssertEqual(paused as? ReviewedPolkaswapPoolSubmissionError, .actionsPaused)
        let unread = try await submitError(makeService(fixture, accepted: { false }), supply())
        XCTAssertEqual(unread as? ReviewedPolkaswapPoolSubmissionError, .disclaimerRequired)
        let other = CovDFixtures.wallet()
        let switched = try await submitError(makeService(fixture, selected: { other }), supply())
        XCTAssertEqual(switched as? ReviewedPolkaswapPoolSubmissionError, .selectedWalletChanged)
        XCTAssertEqual(fixture.registry.substrateConnectionRequests, 0)
    }

    func testFeeEstimationRefusesMissingRuntimeAndWatchOnlySigners() async throws {
        let fixture = try scenario(signing: false)
        let watchOnly = try await feeError(makeService(fixture), supply())
        XCTAssertEqual(watchOnly as? ReviewedPolkaswapPoolSubmissionError, .signerUnavailable)

        let other = CovDFixtures.wallet()
        let switched = try await feeError(makeService(fixture, selected: { other }), supply())
        XCTAssertEqual(switched as? ReviewedPolkaswapPoolSubmissionError, .selectedWalletChanged)

        fixture.registry.connection = nil
        let offline = try await feeError(makeService(fixture), supply())
        XCTAssertEqual(offline as? ReviewedPolkaswapPoolSubmissionError, .runtimeUnavailable)

        fixture.registry.connection = MockConnection()
        fixture.registry.runtime = CovDRuntimeProviderStub()
        let noSnapshot = try await feeError(makeService(fixture), supply())
        XCTAssertEqual(noSnapshot as? ReviewedPolkaswapPoolSubmissionError, .runtimeUnavailable)

        fixture.registry.chains = [:]
        let noChain = try await feeError(makeService(fixture), supply())
        XCTAssertEqual(noChain as? ReviewedPolkaswapPoolSubmissionError, .runtimeUnavailable)
    }

    func testFeeEstimationValidatesThePairAndAmountsBeforeReadingPools() async throws {
        let fixture = try scenario()
        let service = try makeService(fixture)
        let wrongDex = await feeError(service, supply(dexId: "1"))
        XCTAssertEqual(wrongDex as? ReviewedPolkaswapPoolSubmissionError, .invalidPair)
        let samePair = await feeError(service, supply(target: CovDLiquidityFixtures.xor))
        XCTAssertEqual(samePair as? ReviewedPolkaswapPoolSubmissionError, .invalidPair)
        let unknownAsset = await feeError(service, supply(target: "0x" + String(repeating: "09", count: 32)))
        XCTAssertEqual(unknownAsset as? ReviewedPolkaswapPoolSubmissionError, .invalidPair)
        let wrongPrecision = await feeError(service, supply(targetPrecision: 6))
        XCTAssertEqual(wrongPrecision as? ReviewedPolkaswapPoolSubmissionError, .invalidPair)
        let zero = await feeError(service, supply(amount: 0))
        XCTAssertEqual(zero as? ReviewedPolkaswapPoolSubmissionError, .invalidAmount)
        let slippage = await feeError(service, supply(slippage: 100))
        XCTAssertEqual(slippage as? ReviewedPolkaswapPoolSubmissionError, .invalidAmount)
        let zeroRemoval = await feeError(service, removal(amount: 0))
        XCTAssertEqual(zeroRemoval as? ReviewedPolkaswapPoolSubmissionError, .invalidAmount)
        XCTAssertEqual(fixture.registry.substrateConnectionRequests, 0)

        // A valid deposit reaches the exact pool list, which the offline package registry cannot serve.
        let offline = await feeError(service, supply())
        XCTAssertEqual(offline as? CovDTestError, .offline)
        XCTAssertGreaterThan(fixture.registry.substrateConnectionRequests, 0)
    }

    func testWithdrawalNeedsTheRuntimeWithdrawCall() async throws {
        let withoutWithdraw = try scenario(runtime: CovDPoolRuntime(poolCalls: ["deposit_liquidity"]))
        let refused = try await feeError(makeService(withoutWithdraw), removal())
        XCTAssertEqual(refused as? ReviewedPolkaswapPoolSubmissionError, .invalidAmount)
        XCTAssertEqual(withoutWithdraw.registry.substrateConnectionRequests, 0)

        let complete = try scenario()
        let offline = try await feeError(makeService(complete), removal())
        XCTAssertEqual(offline as? CovDTestError, .offline)
    }

    func testSubmissionRebindsTheOperationInsideTheCurrentContext() async throws {
        let fixture = try scenario()
        let offline = try await submitError(makeService(fixture), supply())
        XCTAssertEqual(offline as? CovDTestError, .offline)
        XCTAssertGreaterThan(fixture.registry.substrateConnectionRequests, 0)

        let unsigned = try scenario(signing: false)
        let watchOnly = try await submitError(makeService(unsigned), removal())
        XCTAssertEqual(watchOnly as? ReviewedPolkaswapPoolSubmissionError, .signerUnavailable)
    }
}

final class CovDSwapAuthorizerTests: XCTestCase {
    private func authorizeError(_ authorizer: PolkaswapSubmissionAuthorizer, _ params: PolkaswapPreviewParams) async -> Error? {
        do {
            _ = try await authorizer.authorize(params: params)
            return nil
        } catch {
            return error
        }
    }

    func testAuthorizerRebuildsTheSigningContextBeforeEstimatingTheFee() async throws {
        let wallet = CovDFixtures.wallet()
        let chain = CovDSwapFixtures.chain()
        let registry = CovDRegistryStub()
        registry.chains[chain.chainId] = chain
        registry.runtime = try CovDDemeterRuntime()
        registry.connection = MockConnection()
        let settings = InMemorySettingsManager()
        PolkaswapDisclaimerPolicy.acceptCurrentVersion(in: settings)
        let keystore = InMemoryKeychain()
        var selected: MetaAccountModel? = wallet
        let authorizer = PolkaswapSubmissionAuthorizer(
            chainRegistry: registry, settings: settings, keystore: keystore, accountInfoFetching: nil, selectedWallet: { selected }
        )
        let params = CovDSwapFixtures.params(chain: chain, wallet: wallet)
        guard MultiChainFeaturePolicy.current.polkaswapMutationsEnabled else {
            let paused = await authorizeError(authorizer, params)
            XCTAssertEqual(paused as? PolkaswapSubmissionError, .actionsPaused)
            return
        }

        let watchOnly = await authorizeError(authorizer, params)
        XCTAssertEqual(watchOnly as? PolkaswapSubmissionError, .watchOnly)

        try keystore.addKey(Data(repeating: 3, count: 32), with: chain.keystoreTag(metaId: wallet.metaId))
        // Exact assets, amounts and the swap call are rebuilt; the offline connection then fails the fee estimate.
        let feeFailure = await authorizeError(authorizer, params)
        XCTAssertNotNil(feeFailure)
        XCTAssertNil(feeFailure as? PolkaswapSubmissionError, "\(String(describing: feeFailure))")

        let zero = await authorizeError(authorizer, CovDSwapFixtures.params(chain: chain, wallet: wallet, minMax: 0))
        XCTAssertEqual(zero as? PolkaswapSubmissionError, .invalidAmount)

        let foreign = CovDSwapFixtures.chain(chainId: "covd-foreign")
        let foreignParams = CovDSwapFixtures.params(chain: foreign, wallet: wallet)
        let notSora = await authorizeError(authorizer, foreignParams)
        XCTAssertEqual(notSora as? PolkaswapSubmissionError, .soraRuntimeUnavailable)

        registry.chains[chain.chainId] = CovDFixtures.soraChain(chainId: chain.chainId, assets: [
            AssetModel(
                id: "xor", name: "SORA", symbol: "XOR", precision: 18, currencyId: PolkamarktConstants.feeAssetId,
                isUtility: true, isNative: true, type: .soraAsset
            )
        ])
        let unregistered = await authorizeError(authorizer, params)
        XCTAssertEqual(unregistered as? PolkaswapSubmissionError, .unregisteredAsset)
        registry.chains[chain.chainId] = chain

        let watch = CovDFixtures.wallet(substrate: false)
        selected = watch
        let noAccount = await authorizeError(authorizer, CovDSwapFixtures.params(chain: chain, wallet: watch))
        XCTAssertEqual(noAccount as? PolkaswapSubmissionError, .accountUnavailable)

        let switched = await authorizeError(authorizer, params)
        XCTAssertEqual(switched as? PolkaswapSubmissionError, .selectedWalletChanged)

        selected = wallet
        registry.runtime = CovDRuntimeProviderStub()
        let noSnapshot = await authorizeError(authorizer, params)
        XCTAssertEqual(noSnapshot as? PolkaswapSubmissionError, .soraRuntimeUnavailable)

        let unread = PolkaswapSubmissionAuthorizer(
            chainRegistry: registry, settings: InMemorySettingsManager(), keystore: keystore,
            accountInfoFetching: nil, selectedWallet: { wallet }
        )
        let disclaimer = await authorizeError(unread, params)
        XCTAssertEqual(disclaimer as? PolkaswapSubmissionError, .disclaimerRequired)
    }

    func testDemeterAuthorizerRequiresALocalKeyAndAnAuthoritativeChain() async throws {
        let wallet = CovDFixtures.wallet()
        let chain = CovDFixtures.soraChain(chainId: PolkamarktConstants.soraChainId)
        let registry = CovDRegistryStub()
        registry.chains[chain.chainId] = chain
        registry.runtime = try CovDDemeterRuntime()
        registry.connection = MockConnection()
        let keystore = InMemoryKeychain()
        let authorizer = DemeterMutationSubmissionAuthorizer(
            wallet: wallet,
            chain: chain,
            callBuilder: DemeterMutationCallBuilder(),
            chainRegistry: registry,
            keystore: keystore,
            selectedWallet: { wallet },
            mutationsEnabled: { true }
        )
        func authorizeError() async -> Error? {
            do { _ = try await authorizer.authorize(.claim(pool: CovDDemeterFixtures.makePool())); return nil } catch { return error }
        }
        let unsigned = await authorizeError()
        XCTAssertEqual(unsigned as? DemeterSubmissionError, .signerUnavailable)

        try keystore.addKey(Data(repeating: 4, count: 32), with: chain.keystoreTag(metaId: wallet.metaId))
        // The stub registry offers no chain for mutation authorization, so the first live re-check refuses.
        let unauthoritative = await authorizeError()
        XCTAssertEqual(unauthoritative as? DemeterSubmissionError, .runtimeUnavailable)

        let watch = CovDFixtures.wallet(substrate: false)
        let watchAuthorizer = DemeterMutationSubmissionAuthorizer(
            wallet: watch, chain: chain, callBuilder: DemeterMutationCallBuilder(), chainRegistry: registry,
            keystore: keystore, selectedWallet: { watch }, mutationsEnabled: { true }
        )
        do {
            _ = try await watchAuthorizer.authorize(.claim(pool: CovDDemeterFixtures.makePool()))
            XCTFail("expected a missing SORA account to be refused")
        } catch {
            XCTAssertEqual(error as? DemeterSubmissionError, .signerUnavailable)
        }
    }
}
