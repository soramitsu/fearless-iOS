import XCTest
import SSFModels
import BigInt
@testable import fearless

final class CovCPJIntChoosePoolOutput: StakingPoolJoinChoosePoolInteractorOutput {
    private(set) var receivedPools: [[StakingPool]?] = []
    private(set) var errors: [Error] = []

    func didReceivePools(_ pools: [StakingPool]?) { receivedPools.append(pools) }
    func didReceiveError(_ error: Error) { errors.append(error) }
}

final class CovCPJIntJoinConfigOutput: StakingPoolJoinConfigInteractorOutput {
    let log = CovCPJIntEventLog()

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(info): log.append("account:\(info?.data.free ?? 0)")
        case .failure: log.append("account-error")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(info): log.append("fee:\(info.fee)")
        case .failure: log.append("fee-error")
        }
    }

    func didReceiveMinBond(_ minJoinBond: BigUInt?) {
        log.append("minBond:\(minJoinBond.map { String($0) } ?? "nil")")
    }

    func didReceive(existentialDepositResult: Result<BigUInt, Error>) {
        switch existentialDepositResult {
        case let .success(value): log.append("ed:\(value)")
        case .failure: log.append("ed-error")
        }
    }
}

final class CovCPJIntCreateOutput: StakingPoolCreateInteractorOutput {
    let log = CovCPJIntEventLog()

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) {
        switch result {
        case let .success(info): log.append("account:\(info?.data.free ?? 0)")
        case .failure: log.append("account-error")
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        switch result {
        case let .success(info): log.append("fee:\(info.fee)")
        case .failure: log.append("fee-error")
        }
    }

    func didReceiveMinBond(_ minCreateBond: BigUInt?) {
        log.append("minBond:\(minCreateBond.map { String($0) } ?? "nil")")
    }

    func didReceivePoolMember(_ poolMember: StakingPoolMember?) {
        log.append("member:\(poolMember.map { String($0.poolId.value) } ?? "nil")")
    }

    func didReceiveLastPoolId(_ lastPoolId: UInt32?) {
        log.append("lastPoolId:\(lastPoolId.map { String($0) } ?? "nil")")
    }

    func didReceive(existentialDepositResult: Result<BigUInt, Error>) {
        switch existentialDepositResult {
        case let .success(value): log.append("ed:\(value)")
        case .failure: log.append("ed-error")
        }
    }
}

final class CovCPJPoolInteractorsTests: XCTestCase {
    private var chainAsset: ChainAsset!
    private var wallet: fearless.MetaAccountModel!
    private var operationFactory: CovCPJIntPoolOperationFactory!
    private var operationManager: CovCPJIntOperationManager!
    private var feeProxy: CovCPJIntFeeProxy!
    private var adapter: CovCPJIntAccountAdapter!
    private var depositService: CovCPJIntDepositService!
    private var callFactory: SubstrateCallFactoryDefault!

    override func setUp() {
        super.setUp()
        chainAsset = CovCPJFixtures.chainAsset(precision: 10)
        wallet = CovCPJFixtures.wallet()
        operationFactory = CovCPJIntPoolOperationFactory()
        operationManager = CovCPJIntOperationManager()
        feeProxy = CovCPJIntFeeProxy()
        adapter = CovCPJIntAccountAdapter()
        depositService = CovCPJIntDepositService()
        callFactory = SubstrateCallFactoryDefault(runtimeService: CovCPJIntRuntimeProvider())
    }

    override func tearDown() {
        chainAsset = nil
        wallet = nil
        operationFactory = nil
        operationManager = nil
        feeProxy = nil
        adapter = nil
        depositService = nil
        callFactory = nil
        super.tearDown()
    }

    private var accountId: AccountId? {
        wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId
    }

    // MARK: - Choose pool

    func testChoosePoolInteractorDeliversPools() {
        operationFactory.bondedPools = .success([CovCPJFixtures.pool(id: "1", name: "A", points: 1, members: 1)])
        let interactor = StakingPoolJoinChoosePoolInteractor(
            stakingPoolOperationFactory: operationFactory,
            operationManager: operationManager
        )
        let output = CovCPJIntChoosePoolOutput()

        interactor.setup(with: output)
        CovCPJFixtures.spin { !output.receivedPools.isEmpty }

        XCTAssertEqual(output.receivedPools.first??.map(\.id), ["1"])
        XCTAssertTrue(output.errors.isEmpty)
    }

    func testChoosePoolInteractorDeliversError() {
        operationFactory.bondedPools = .failure(CovCPJTestError.failed)
        let interactor = StakingPoolJoinChoosePoolInteractor(
            stakingPoolOperationFactory: operationFactory,
            operationManager: operationManager
        )
        let output = CovCPJIntChoosePoolOutput()

        interactor.setup(with: output)
        CovCPJFixtures.spin { !output.errors.isEmpty }

        XCTAssertEqual(output.errors.count, 1)
        XCTAssertTrue(output.receivedPools.isEmpty)
    }

    // MARK: - Join config

    private func makeJoinConfigInteractor() -> StakingPoolJoinConfigInteractor {
        StakingPoolJoinConfigInteractor(
            accountInfoSubscriptionAdapter: adapter,
            chainAsset: chainAsset,
            wallet: wallet,
            extrinsicService: CovCPJIntExtrinsicService(),
            feeProxy: feeProxy,
            stakingPoolOperationFactory: operationFactory,
            operationManager: operationManager,
            existentialDepositService: depositService,
            callFactory: callFactory
        )
    }

    func testJoinConfigSetupSubscribesAndFetchesData() throws {
        adapter.accountInfo = CovCPJFixtures.accountInfo(free: 500)
        operationFactory.minJoinBond = 7
        let interactor = makeJoinConfigInteractor()
        let output = CovCPJIntJoinConfigOutput()

        interactor.setup(with: output)
        CovCPJFixtures.spin { output.log.contains("minBond:7") }

        XCTAssertTrue(feeProxy.delegate === interactor)
        XCTAssertEqual(adapter.subscribedAccountIds, [try XCTUnwrap(accountId)])
        XCTAssertTrue(output.log.contains("account:500"))
        XCTAssertTrue(output.log.contains("ed:10000000000"))
        XCTAssertTrue(output.log.contains("minBond:7"))
    }

    func testJoinConfigEstimatesFeeAndForwardsResults() throws {
        let interactor = makeJoinConfigInteractor()
        let output = CovCPJIntJoinConfigOutput()
        depositService.result = .failure(CovCPJTestError.failed)
        interactor.setup(with: output)

        interactor.estimateFee()
        interactor.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 5)), for: "id")
        interactor.handleAccountInfo(result: .failure(CovCPJTestError.failed), accountId: Data(), chainAsset: chainAsset)

        let expectedIdentifier = callFactory.joinPool(poolId: "\(UInt32.max)", amount: 1).callName
        XCTAssertEqual(feeProxy.reuseIdentifiers, [expectedIdentifier])
        XCTAssertTrue(output.log.contains("fee:5"))
        XCTAssertTrue(output.log.contains("account-error"))
        XCTAssertTrue(output.log.contains("ed-error"))
    }

    // MARK: - Create

    private func makeCreateInteractor() -> StakingPoolCreateInteractor {
        StakingPoolCreateInteractor(
            accountInfoSubscriptionAdapter: adapter,
            chainAsset: chainAsset,
            wallet: wallet,
            extrinsicService: CovCPJIntExtrinsicService(),
            feeProxy: feeProxy,
            stakingPoolOperationFactory: operationFactory,
            operationManager: operationManager,
            existentialDepositService: depositService,
            callFactory: callFactory
        )
    }

    func testCreateSetupFetchesMemberPoolIdBondAndBalance() throws {
        adapter.accountInfo = CovCPJFixtures.accountInfo(free: 900)
        operationFactory.poolMember = try CovCPJFixtures.poolMember(poolId: 2, points: "10")
        operationFactory.lastPoolId = 4
        operationFactory.minCreateBond = 9
        let interactor = makeCreateInteractor()
        let output = CovCPJIntCreateOutput()

        interactor.setup(with: output)
        CovCPJFixtures.spin {
            output.log.contains("member:2") && output.log.contains("lastPoolId:4") && output.log.contains("minBond:9")
        }

        XCTAssertTrue(feeProxy.delegate === interactor)
        let expectedAccountId = try XCTUnwrap(accountId)
        XCTAssertEqual(operationFactory.memberRequests, [expectedAccountId])
        XCTAssertEqual(adapter.subscribedAccountIds, [expectedAccountId])
        XCTAssertTrue(output.log.contains("member:2"))
        XCTAssertTrue(output.log.contains("lastPoolId:4"))
        XCTAssertTrue(output.log.contains("minBond:9"))
        XCTAssertTrue(output.log.contains("account:900"))
        XCTAssertTrue(output.log.contains("ed:10000000000"))
    }

    func testCreateEstimateFeeNeedsCompleteInput() {
        let interactor = makeCreateInteractor()
        let output = CovCPJIntCreateOutput()
        interactor.setup(with: output)

        interactor.estimateFee(amount: nil, poolName: "Pool", poolId: 3)
        interactor.estimateFee(amount: 100, poolName: "Pool", poolId: nil)
        interactor.estimateFee(amount: 100, poolName: "Pool \u{2713}", poolId: 3)
        XCTAssertTrue(feeProxy.reuseIdentifiers.isEmpty)

        interactor.estimateFee(amount: 100, poolName: "Pool", poolId: 3)
        XCTAssertEqual(feeProxy.reuseIdentifiers, ["Pool100"])
    }

    func testCreateForwardsFeeAndAccountResults() {
        let interactor = makeCreateInteractor()
        let output = CovCPJIntCreateOutput()
        interactor.setup(with: output)

        interactor.didReceiveFee(result: .failure(CovCPJTestError.failed), for: "id")
        interactor.handleAccountInfo(
            result: .success(CovCPJFixtures.accountInfo(free: 33)),
            accountId: Data(),
            chainAsset: chainAsset
        )

        XCTAssertTrue(output.log.contains("fee-error"))
        XCTAssertTrue(output.log.contains("account:33"))
    }
}
