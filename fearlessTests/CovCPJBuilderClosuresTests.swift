import XCTest
import RobinHood
import SSFModels
import SSFUtils
import BigInt
@testable import fearless

/// Records the calls an interactor's extrinsic builder closure adds.
final class CovCPJBCBuilder: ExtrinsicBuilderProtocol {
    private(set) var addedCalls: [String] = []

    func with<A: Codable>(address _: A) throws -> Self { self }
    func with(nonce _: UInt32) -> Self { self }
    func with(era _: Era, blockHash _: String) -> Self { self }
    func with(tip _: BigUInt) -> Self { self }
    func with(appId _: BigUInt) -> Self { self }
    func with(shouldUseAtomicBatch _: Bool) -> Self { self }

    func adding<T: RuntimeCallable>(call: T) throws -> Self {
        addedCalls.append("\(call.moduleName).\(call.callName)")
        return self
    }

    func adding(rawCall _: Data) throws -> Self { self }

    func signing(
        by _: (Data) throws -> Data,
        of _: CryptoType,
        using _: DynamicScaleEncoding,
        metadata _: RuntimeMetadata
    ) throws -> Self {
        self
    }

    func build(encodingBy _: DynamicScaleEncoding, metadata _: RuntimeMetadata) throws -> Data { Data() }
    func buildSignature(encodingBy _: DynamicScaleEncoding, metadata _: RuntimeMetadata) throws -> Data { Data() }
}

final class CovCPJBCFeeProxy: ExtrinsicFeeProxyProtocol {
    weak var delegate: ExtrinsicFeeProxyDelegate?
    private(set) var closures: [ExtrinsicBuilderClosure] = []

    func estimateFee(
        using _: ExtrinsicServiceProtocol,
        reuseIdentifier _: ExtrinsicFeeId,
        setupBy closure: @escaping ExtrinsicBuilderClosure
    ) {
        closures.append(closure)
    }
}

final class CovCPJBCExtrinsicService: ExtrinsicServiceProtocol {
    private(set) var submitted: [ExtrinsicBuilderClosure] = []

    func estimateFee(
        _: @escaping ExtrinsicBuilderClosure,
        runningIn _: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeClosure
    ) {
        completionClosure(.failure(CovCPJTestError.failed))
    }

    func estimateFee(
        _: @escaping ExtrinsicBuilderIndexedClosure,
        runningIn _: DispatchQueue,
        numberOfExtrinsics _: Int,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    ) {
        completionClosure([])
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer _: SigningWrapperProtocol,
        runningIn _: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitClosure
    ) {
        submitted.append(closure)
        completionClosure(.success("0x0"))
    }

    func submit(
        _: @escaping ExtrinsicBuilderIndexedClosure,
        signer _: SigningWrapperProtocol,
        runningIn _: DispatchQueue,
        numberOfExtrinsics _: Int,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    ) {
        completionClosure([])
    }

    func submitAndWatch(
        _: @escaping ExtrinsicBuilderClosure,
        signer _: SigningWrapperProtocol,
        runningIn _: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitAndWatchClosure
    ) {
        completionClosure(.success("0x0"), nil)
    }
}

final class CovCPJBuilderClosuresTests: XCTestCase {
    private var chainAsset: ChainAsset!
    private var wallet: fearless.MetaAccountModel!
    private var feeProxy: CovCPJBCFeeProxy!
    private var service: CovCPJBCExtrinsicService!
    private var callFactory: SubstrateCallFactoryDefault!

    override func setUp() {
        super.setUp()
        chainAsset = CovCPJFixtures.chainAsset(precision: 10)
        wallet = CovCPJFixtures.wallet()
        feeProxy = CovCPJBCFeeProxy()
        service = CovCPJBCExtrinsicService()
        callFactory = SubstrateCallFactoryDefault(runtimeService: CovCPJIntRuntimeProvider())
    }

    override func tearDown() {
        chainAsset = nil
        wallet = nil
        feeProxy = nil
        service = nil
        callFactory = nil
        super.tearDown()
    }

    private var joinCall: String {
        let call = callFactory.joinPool(poolId: "1", amount: 1)
        return "\(call.moduleName).\(call.callName)"
    }

    private func run(_ closure: ExtrinsicBuilderClosure?) throws -> [String] {
        let builder = CovCPJBCBuilder()
        _ = try XCTUnwrap(closure)(builder)
        return builder.addedCalls
    }

    func testJoinConfigFeeClosureAddsJoinCall() throws {
        let interactor = StakingPoolJoinConfigInteractor(
            accountInfoSubscriptionAdapter: CovCPJIntAccountAdapter(),
            chainAsset: chainAsset,
            wallet: wallet,
            extrinsicService: service,
            feeProxy: feeProxy,
            stakingPoolOperationFactory: CovCPJIntPoolOperationFactory(),
            operationManager: CovCPJIntOperationManager(),
            existentialDepositService: CovCPJIntDepositService(),
            callFactory: callFactory
        )

        interactor.estimateFee()

        XCTAssertEqual(try run(feeProxy.closures.first), [joinCall])
    }

    func testJoinConfirmFeeAndSubmitClosuresAddJoinCall() throws {
        let interactor = StakingPoolJoinConfirmInteractor(
            chainAsset: chainAsset,
            wallet: wallet,
            extrinsicService: service,
            feeProxy: feeProxy,
            amount: 5,
            pool: CovCPJFixtures.pool(id: "1", name: "P", points: 1, members: 1),
            signingWrapper: CovCPJIntSigner(),
            runtimeService: CovCPJIntRuntimeProvider(),
            operationManager: CovCPJIntOperationManager(),
            validatorOperationFactory: CovCPJIntValidatorFactory(),
            callFactory: callFactory
        )

        interactor.estimateFee()
        interactor.submit()

        XCTAssertEqual(try run(feeProxy.closures.first), [joinCall])
        XCTAssertEqual(try run(service.submitted.first), [joinCall])
    }

    func testPoolRolesClosuresAddUpdateRolesCall() throws {
        let interactor = PoolRolesConfirmInteractor(
            extrinsicService: service,
            feeProxy: feeProxy,
            poolId: "2",
            roles: CovCPJFixtures.roles(nominator: Data(repeating: 3, count: 32)),
            signingWrapper: CovCPJIntSigner(),
            chainAsset: chainAsset,
            accountRepository: AnyDataProviderRepository(CovCPJIntAccountRepository()),
            operationManager: CovCPJIntOperationManager(),
            callFactory: callFactory
        )
        let expected = "\(CallCodingPath.nominationPoolUpdateRoles.moduleName).\(CallCodingPath.nominationPoolUpdateRoles.callName)"

        interactor.estimateFee()
        interactor.submit()

        XCTAssertEqual(try run(feeProxy.closures.first), [expected])
        XCTAssertEqual(try run(service.submitted.first), [expected])
    }

    func testCreateFeeClosureNeedsRuntimeMetadata() throws {
        let interactor = StakingPoolCreateInteractor(
            accountInfoSubscriptionAdapter: CovCPJIntAccountAdapter(),
            chainAsset: chainAsset,
            wallet: wallet,
            extrinsicService: service,
            feeProxy: feeProxy,
            stakingPoolOperationFactory: CovCPJIntPoolOperationFactory(),
            operationManager: CovCPJIntOperationManager(),
            existentialDepositService: CovCPJIntDepositService(),
            callFactory: callFactory
        )

        interactor.estimateFee(amount: 10, poolName: "Pool", poolId: 1)

        let closure = try XCTUnwrap(feeProxy.closures.first)
        let builder = CovCPJBCBuilder()
        let failed: Bool = withExtendedLifetime(interactor) { (try? closure(builder)) == nil }
        XCTAssertTrue(failed)
        XCTAssertTrue(builder.addedCalls.isEmpty)
    }

    func testCreateConfirmSubmitClosureNeedsRuntimeMetadata() throws {
        let data = StakingPoolCreateData(
            poolId: 1,
            poolName: "Pool",
            amount: 2,
            root: wallet,
            nominator: wallet,
            bouncer: wallet,
            chainAsset: chainAsset
        )
        let interactor = StakingPoolCreateConfirmInteractor(
            stakingLocalSubscriptionFactory: CovCPJCCSubscriptionFactory(),
            extrinsicService: service,
            feeProxy: feeProxy,
            createData: data,
            signingWrapper: CovCPJIntSigner(),
            callFactory: callFactory
        )

        interactor.submit()

        let closure = try XCTUnwrap(service.submitted.first)
        let builder = CovCPJBCBuilder()
        let failed: Bool = withExtendedLifetime(interactor) { (try? closure(builder)) == nil }
        XCTAssertTrue(failed)
        XCTAssertTrue(builder.addedCalls.isEmpty)
    }
}
