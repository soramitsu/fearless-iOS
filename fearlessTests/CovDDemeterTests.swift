import BigInt
import Foundation
import SoraKeystore
import SSFModels
import UIKit
import XCTest

@testable import fearless

enum CovDDemeterFixtures {
    static let base = CovDFixtures.xorAssetId
    static let pool = CovDFixtures.valAssetId
    static let reward = CovDFixtures.pswapAssetId

    static let complete = DemeterRuntimeCapabilities(
        palletAvailable: true,
        storage: ["Pools", "Token_Infos", "UserInfos"],
        calls: ["deposit", "withdraw", "get_rewards"]
    )

    static func makePool(poolAsset: String = pool, isRemoved: Bool = false, isFarm: Bool = true) -> DemeterPool {
        DemeterPool(
            identity: DemeterPoolIdentity(baseAssetId: base, poolAssetId: poolAsset, rewardAssetId: reward, isFarm: isFarm),
            multiplier: "1",
            depositFee: "0",
            isCore: true,
            totalTokensInPool: "4000000000000000000",
            rewards: "0",
            rewardsToBeDistributed: "0",
            isRemoved: isRemoved
        )
    }

    static func position(_ pool: DemeterPool, pooled: String = "10", rewards: String = "5") -> DemeterAccountPosition {
        DemeterAccountPosition(identity: pool.identity, pooledTokens: pooled, rewards: rewards)
    }

    static func snapshot(
        pools: [DemeterPool],
        positions: [DemeterAccountPosition] = [],
        capabilities: DemeterRuntimeCapabilities = complete
    ) -> DemeterSnapshot {
        DemeterSnapshot(pools: pools, rewardTokens: [:], positions: positions, capabilities: capabilities)
    }

    static func balances(
        poolAsset: String = pool,
        poolSpendable: BigUInt? = 1000,
        feeSpendable: BigUInt? = 100,
        feeChain: String = PolkamarktConstants.soraChainId
    ) -> DemeterAuthoritativeBalances {
        DemeterAuthoritativeBalances(
            poolAssetKey: AssetKey(ecosystem: "substrate", chainId: PolkamarktConstants.soraChainId, assetId: poolAsset),
            feeAssetKey: AssetKey(ecosystem: "substrate", chainId: feeChain, assetId: CovDFixtures.xorAssetId),
            poolAssetSpendable: poolSpendable,
            feeSpendable: feeSpendable
        )
    }

    static let token = DemeterRewardToken(
        assetId: reward,
        farmsTotalMultiplier: "2",
        stakingTotalMultiplier: "0",
        tokenPerBlock: "1000000000000000000",
        farmsAllocation: "500000000000000000",
        stakingAllocation: "0"
    )

    /// A chain whose catalog ids are the runtime asset ids, with exact cached prices.
    static func pricedChain() -> ChainModel {
        let poolPriceId = "covd-val-\(UUID().uuidString)"
        let rewardPriceId = "covd-pswap-\(UUID().uuidString)"
        ExactAssetPriceCache.shared.upsert([
            CovDFixtures.price("2", priceId: poolPriceId),
            CovDFixtures.price("3", priceId: rewardPriceId)
        ])
        return CovDFixtures.soraChain(assets: [
            CovDFixtures.asset(id: base, symbol: "XOR", currencyId: CovDFixtures.xorAssetId),
            CovDFixtures.asset(id: pool, symbol: "VAL", currencyId: pool, priceId: poolPriceId),
            CovDFixtures.asset(id: reward, symbol: "PSWAP", currencyId: reward, priceId: rewardPriceId)
        ])
    }
}

final class CovDDemeterLogicTests: XCTestCase {
    typealias CovDF = CovDDemeterFixtures

    func testCapabilitiesAndPositionActivity() {
        XCTAssertTrue(CovDF.complete.hasStorage("TokenInfos"))
        XCTAssertTrue(CovDF.complete.hasCall("getRewards"))
        XCTAssertEqual(CovDF.complete.resolvedCallName("getRewards"), "get_rewards")
        XCTAssertTrue(CovDF.complete.canBrowse)
        XCTAssertTrue(CovDF.complete.canMutate)
        XCTAssertNil(CovDF.complete.unavailableReason)
        XCTAssertEqual(
            DemeterRuntimeCapabilities(palletAvailable: false, storage: [], calls: []).unavailableReason,
            "The connected SORA runtime does not expose Demeter Farming."
        )
        XCTAssertEqual(
            DemeterRuntimeCapabilities(palletAvailable: true, storage: ["Pools"], calls: []).unavailableReason,
            "Demeter pool storage is unavailable on this SORA runtime."
        )
        XCTAssertEqual(
            DemeterRuntimeCapabilities(palletAvailable: true, storage: ["Pools", "TokenInfos"], calls: ["deposit"]).unavailableReason,
            "Pool discovery is available, but this runtime cannot deposit, withdraw, or claim."
        )
        let pool = CovDF.makePool()
        XCTAssertTrue(CovDF.position(pool, pooled: "0", rewards: "1").isActive)
        XCTAssertTrue(CovDF.position(pool, pooled: "1", rewards: "0").isActive)
        XCTAssertFalse(CovDF.position(pool, pooled: "0", rewards: "x").isActive)
    }

    func testMutationAuthorizationFieldsAndErrors() {
        let pool = CovDF.makePool()
        XCTAssertEqual(
            DemeterMutation.deposit(pool: pool, amount: "5").authorizationFields,
            ["deposit", CovDF.base, CovDF.pool, CovDF.reward, "true", "5"]
        )
        XCTAssertEqual(DemeterMutation.withdraw(pool: pool, amount: "6").authorizationFields.first, "withdraw")
        XCTAssertEqual(DemeterMutation.claim(pool: pool).authorizationFields.last, "")

        let all: [DemeterSubmissionError] = [
            .runtimeUnavailable, .signerUnavailable, .selectedWalletChanged, .runtimeCallUnavailable, .poolUnavailable,
            .poolClosed, .invalidAmount, .positionUnavailable, .insufficientPosition, .claimUnavailable,
            .balanceUnavailable, .insufficientAsset, .insufficientFee
        ]
        XCTAssertEqual(Set(all.compactMap(\.errorDescription)).count, all.count)
        XCTAssertEqual(DemeterSubmissionError.invalidAmount.errorDescription, "Enter a positive Demeter amount.")
    }

    func testBindRejectsEveryStaleOrInvalidRequest() throws {
        let pool = CovDF.makePool()
        let removed = CovDF.makePool(isRemoved: true)
        func bindError(_ mutation: DemeterMutation, _ snapshot: DemeterSnapshot) -> DemeterSubmissionError? {
            do { _ = try DemeterMutationBoundaryValidator.bind(mutation, to: snapshot); return nil } catch {
                return error as? DemeterSubmissionError
            }
        }
        let noBrowse = CovDF.snapshot(pools: [pool], capabilities: DemeterRuntimeCapabilities(palletAvailable: true, storage: [], calls: []))
        XCTAssertEqual(bindError(.claim(pool: pool), noBrowse), .runtimeUnavailable)
        let noCall = CovDF.snapshot(pools: [pool], capabilities: DemeterRuntimeCapabilities(
            palletAvailable: true, storage: ["Pools", "TokenInfos"], calls: ["deposit"]
        ))
        XCTAssertEqual(bindError(.claim(pool: pool), noCall), .runtimeCallUnavailable)
        XCTAssertEqual(bindError(.claim(pool: pool), CovDF.snapshot(pools: [])), .poolUnavailable)
        XCTAssertEqual(bindError(.claim(pool: pool), CovDF.snapshot(pools: [pool, pool])), .poolUnavailable)
        XCTAssertEqual(bindError(.deposit(pool: pool, amount: "0"), CovDF.snapshot(pools: [pool])), .invalidAmount)
        XCTAssertEqual(bindError(.deposit(pool: removed, amount: "1"), CovDF.snapshot(pools: [removed])), .poolClosed)
        XCTAssertEqual(bindError(.withdraw(pool: pool, amount: "x"), CovDF.snapshot(pools: [pool])), .invalidAmount)
        XCTAssertEqual(bindError(.withdraw(pool: pool, amount: "1"), CovDF.snapshot(pools: [pool])), .positionUnavailable)
        XCTAssertEqual(
            bindError(.withdraw(pool: pool, amount: "11"), CovDF.snapshot(pools: [pool], positions: [CovDF.position(pool)])),
            .insufficientPosition
        )
        XCTAssertEqual(bindError(.claim(pool: pool), CovDF.snapshot(pools: [pool])), .positionUnavailable)
        XCTAssertEqual(
            bindError(.claim(pool: pool), CovDF.snapshot(pools: [pool], positions: [CovDF.position(pool, rewards: "0")])),
            .claimUnavailable
        )

        let current = DemeterPool(
            identity: DemeterPoolIdentity(baseAssetId: CovDF.base.uppercased(), poolAssetId: CovDF.pool, rewardAssetId: CovDF.reward, isFarm: true),
            multiplier: "9", depositFee: "0", isCore: false, totalTokensInPool: "1", rewards: "0",
            rewardsToBeDistributed: "0", isRemoved: false
        )
        let bound = try DemeterMutationBoundaryValidator.bind(.deposit(pool: pool, amount: "3"), to: CovDF.snapshot(pools: [current]))
        guard case let .deposit(boundPool, amount) = bound else { return XCTFail("expected deposit") }
        XCTAssertEqual(boundPool.multiplier, "9")
        XCTAssertEqual(amount, "3")
        XCTAssertNoThrow(try DemeterMutationBoundaryValidator.bind(
            .withdraw(pool: pool, amount: "10"), to: CovDF.snapshot(pools: [pool], positions: [CovDF.position(pool)])
        ))
    }

    func testValidateChecksExactBalancesAndFees() throws {
        let pool = CovDF.makePool()
        let xorPool = CovDF.makePool(poolAsset: CovDFixtures.xorAssetId)
        let snapshot = CovDF.snapshot(pools: [pool, xorPool], positions: [CovDF.position(pool)])
        func error(_ mutation: DemeterMutation, _ balances: DemeterAuthoritativeBalances, fee: BigUInt = 10) -> DemeterSubmissionError? {
            do {
                _ = try DemeterMutationBoundaryValidator.validate(mutation, snapshot: snapshot, balances: balances, requiredFee: fee)
                return nil
            } catch { return error as? DemeterSubmissionError }
        }
        XCTAssertEqual(error(.claim(pool: pool), CovDF.balances(), fee: 0), .runtimeUnavailable)
        XCTAssertEqual(error(.claim(pool: pool), CovDF.balances(feeChain: "other")), .balanceUnavailable)
        XCTAssertEqual(error(.claim(pool: pool), CovDF.balances(feeSpendable: nil)), .balanceUnavailable)
        XCTAssertEqual(error(.deposit(pool: pool, amount: "5"), CovDF.balances(poolAsset: CovDF.reward)), .balanceUnavailable)
        XCTAssertEqual(error(.deposit(pool: pool, amount: "5"), CovDF.balances(poolSpendable: nil)), .balanceUnavailable)
        XCTAssertEqual(error(.deposit(pool: pool, amount: "5000"), CovDF.balances()), .insufficientAsset)
        XCTAssertEqual(error(.deposit(pool: pool, amount: "5"), CovDF.balances(feeSpendable: 9)), .insufficientFee)
        XCTAssertEqual(
            error(.deposit(pool: xorPool, amount: "995"), CovDF.balances(poolAsset: CovDFixtures.xorAssetId)),
            .insufficientAsset
        )
        XCTAssertNil(error(.deposit(pool: xorPool, amount: "990"), CovDF.balances(poolAsset: CovDFixtures.xorAssetId)))
        XCTAssertEqual(error(.withdraw(pool: pool, amount: "5"), CovDF.balances(feeSpendable: 1)), .insufficientFee)
        XCTAssertNil(error(.claim(pool: pool), CovDF.balances()))
        XCTAssertNil(error(.deposit(pool: pool, amount: "5"), CovDF.balances()))
    }

    func testCallBuilderUsesRuntimeNamesAndRefusesInvalidCalls() throws {
        let builder = DemeterMutationCallBuilder()
        let pool = CovDF.makePool()
        XCTAssertThrowsError(try builder.builder(
            for: .claim(pool: pool), capabilities: DemeterRuntimeCapabilities(palletAvailable: false, storage: [], calls: [])
        )) { XCTAssertEqual($0 as? DemeterSubmissionError, .runtimeUnavailable) }
        XCTAssertThrowsError(try builder.builder(for: .deposit(pool: CovDF.makePool(isRemoved: true), amount: "1"), capabilities: CovDF.complete))
        XCTAssertThrowsError(try builder.builder(for: .deposit(pool: pool, amount: "0"), capabilities: CovDF.complete))
        XCTAssertThrowsError(try builder.builder(for: .withdraw(pool: pool, amount: "0"), capabilities: CovDF.complete))
        let noClaim = DemeterRuntimeCapabilities(palletAvailable: true, storage: [], calls: ["deposit"])
        XCTAssertThrowsError(try builder.builder(for: .claim(pool: pool), capabilities: noClaim)) {
            XCTAssertEqual($0 as? DemeterSubmissionError, .runtimeCallUnavailable)
        }

        let cases: [(DemeterMutation, String)] = [
            (.deposit(pool: pool, amount: "7"), "deposit"),
            (.withdraw(pool: pool, amount: "7"), "withdraw"),
            (.claim(pool: pool), "get_rewards")
        ]
        for (mutation, name) in cases {
            let spy = CovDExtrinsicBuilderSpy()
            _ = try builder.builder(for: mutation, capabilities: CovDF.complete)(spy)
            XCTAssertEqual(spy.calls.first?.module, DemeterConstants.moduleName)
            XCTAssertEqual(spy.calls.first?.call, name)
            XCTAssertEqual(spy.argsObject(at: 0)?["is_farm"] as? Bool, true)
        }
    }

    func testMutationServiceRechecksTheKillSwitchAroundAuthorization() async throws {
        let executor = CovDDemeterExecutorSpy()
        var enabled = false
        var guardCalls = 0
        let authorizer = CovDDemeterAuthorizerStub {
            DemeterAuthorizedSubmission(builder: { $0 }, executor: executor, finalGuard: { guardCalls += 1 })
        }
        let service = DemeterMutationService(
            initialCapabilities: CovDF.complete,
            callBuilder: DemeterMutationCallBuilder(),
            submissionAuthorizer: authorizer,
            initialExecutor: executor,
            mutationsEnabled: { enabled }
        )
        let mutation = DemeterMutation.claim(pool: CovDF.makePool())
        let fee = try await service.estimateFee(for: mutation)
        XCTAssertEqual(fee.fee, "11")

        do { _ = try await service.submit(mutation); XCTFail("paused") } catch {
            XCTAssertEqual(error.localizedDescription, PolkamarktServiceError.actionsPaused.localizedDescription)
        }
        enabled = true
        let hash = try await service.submit(mutation)
        XCTAssertEqual(hash, "0xdemeter")
        XCTAssertEqual(guardCalls, 1)
        authorizer.onAuthorize = { enabled = false }
        do { _ = try await service.submit(mutation); XCTFail("paused after authorization") } catch {
            XCTAssertEqual(error.localizedDescription, PolkamarktServiceError.actionsPaused.localizedDescription)
        }
        XCTAssertEqual(executor.submitCount, 1)
        XCTAssertEqual(executor.estimateCount, 1)
    }

    func testSubmissionAuthorizerFailsClosedOnPolicyWalletChainAndRuntime() async {
        let wallet = CovDFixtures.wallet()
        let registry = CovDRegistryStub()
        func authorizeError(
            chain: ChainModel,
            enabled: Bool = true,
            selected: MetaAccountModel? = nil
        ) async -> Error? {
            let authorizer = DemeterMutationSubmissionAuthorizer(
                wallet: wallet,
                chain: chain,
                callBuilder: DemeterMutationCallBuilder(),
                chainRegistry: registry,
                keystore: InMemoryKeychain(),
                selectedWallet: { selected ?? wallet },
                mutationsEnabled: { enabled }
            )
            do { _ = try await authorizer.authorize(.claim(pool: CovDF.makePool())); return nil } catch { return error }
        }
        let sora = CovDFixtures.soraChain(chainId: PolkamarktConstants.soraChainId)
        let paused = await authorizeError(chain: sora, enabled: false)
        XCTAssertEqual(paused?.localizedDescription, PolkamarktServiceError.actionsPaused.localizedDescription)
        let switched = await authorizeError(chain: sora, selected: CovDFixtures.wallet())
        XCTAssertEqual(switched as? DemeterSubmissionError, .selectedWalletChanged)
        let otherChain = await authorizeError(chain: CovDFixtures.soraChain())
        XCTAssertEqual(otherChain as? DemeterSubmissionError, .runtimeUnavailable)
        let missingChain = await authorizeError(chain: sora)
        XCTAssertEqual(missingChain as? DemeterSubmissionError, .runtimeUnavailable)
        registry.chains[sora.chainId] = sora
        registry.runtime = CovDRuntimeProviderStub()
        registry.connection = MockConnection()
        let noSnapshot = await authorizeError(chain: sora)
        XCTAssertEqual(noSnapshot as? DemeterSubmissionError, .runtimeUnavailable)
    }

    func testBalanceProviderReadsExactAssetsOnly() async throws {
        let chain = CovDFixtures.soraChain()
        let service = CovDAccountInfoServiceStub()
        let val = try XCTUnwrap(CovDFixtures.chainAsset(chain, currencyId: CovDF.pool))
        let xor = try XCTUnwrap(CovDFixtures.chainAsset(chain, currencyId: CovDFixtures.xorAssetId))
        service.infos = [val.chainAssetId: AccountInfo(ethBalance: 40), xor.chainAssetId: AccountInfo(ethBalance: 4)]
        let identity = CovDF.makePool().identity

        let full = await DemeterAuthoritativeBalanceProvider(wallet: CovDFixtures.wallet(), chain: chain, accountInfoRemoteService: service)
            .balances(for: identity)
        XCTAssertEqual(full.poolAssetSpendable, 40)
        XCTAssertEqual(full.feeSpendable, 4)
        XCTAssertEqual(full.poolAssetKey, val.assetKey)

        let noAccount = await DemeterAuthoritativeBalanceProvider(
            wallet: CovDFixtures.wallet(substrate: false), chain: chain, accountInfoRemoteService: service
        ).balances(for: identity)
        XCTAssertNil(noAccount.feeSpendable)
        XCTAssertEqual(noAccount.poolAssetKey, val.assetKey)

        let noFee = CovDFixtures.soraChain(assets: [CovDFixtures.asset(id: "val", symbol: "VAL", currencyId: CovDF.pool)])
        let missingFee = await DemeterAuthoritativeBalanceProvider(wallet: CovDFixtures.wallet(), chain: noFee, accountInfoRemoteService: service)
            .balances(for: identity)
        XCTAssertNil(missingFee.feeAssetKey)
        XCTAssertEqual(service.fetchCount, 1)
    }

    func testRuntimeServiceNeedsRuntimeAndConnection() async {
        let registry = CovDRegistryStub()
        XCTAssertNil(DemeterRuntimeService(wallet: CovDFixtures.wallet(), chain: CovDFixtures.soraChain(), chainRegistry: registry))
        registry.runtime = CovDRuntimeProviderStub()
        registry.connection = MockConnection()
        let service = DemeterRuntimeService(wallet: CovDFixtures.wallet(), chain: CovDFixtures.soraChain(), chainRegistry: registry)
        XCTAssertNotNil(service)
        do {
            _ = try await service?.snapshot()
            XCTFail("dummy runtime cannot provide metadata")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}

final class CovDDemeterExecutorSpy: DemeterMutationExtrinsicExecuting {
    private(set) var estimateCount = 0
    private(set) var submitCount = 0

    func estimateFee(_: @escaping ExtrinsicBuilderClosure) async throws -> RuntimeDispatchInfo {
        estimateCount += 1
        return RuntimeDispatchInfo(feeValue: BigUInt(11))
    }

    func submit(_: @escaping ExtrinsicBuilderClosure) async throws -> String {
        submitCount += 1
        return "0xdemeter"
    }
}

final class CovDDemeterAuthorizerStub: DemeterMutationSubmissionAuthorizing {
    private let make: () -> DemeterAuthorizedSubmission
    var onAuthorize: () -> Void = {}

    init(make: @escaping () -> DemeterAuthorizedSubmission) {
        self.make = make
    }

    func authorize(_: DemeterMutation) async throws -> DemeterAuthorizedSubmission {
        onAuthorize()
        return make()
    }
}
