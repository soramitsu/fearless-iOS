import XCTest
import RobinHood
import SSFModels
import BigInt
@testable import fearless

final class CovCPJCCRepository<T: Identifiable>: DataProviderRepositoryProtocol {
    typealias Model = T

    private func operation<R>(_ value: R) -> BaseOperation<R> {
        let operation = BaseOperation<R>()
        operation.result = .success(value)
        return operation
    }

    func fetchOperation(by _: @escaping () throws -> [String], options _: RepositoryFetchOptions) -> BaseOperation<[T]> {
        operation([])
    }

    func fetchOperation(by _: @escaping () throws -> String, options _: RepositoryFetchOptions) -> BaseOperation<T?> {
        operation(nil)
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[T]> { operation([]) }

    func fetchOperation(by _: RepositorySliceRequest, options _: RepositoryFetchOptions) -> BaseOperation<[T]> {
        operation([])
    }

    func saveOperation(_: @escaping () throws -> [T], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        operation(())
    }

    func saveBatchOperation(_: @escaping () throws -> [T], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        operation(())
    }

    func replaceOperation(_: @escaping () throws -> [T]) -> BaseOperation<Void> { operation(()) }
    func fetchCountOperation() -> BaseOperation<Int> { operation(0) }
    func deleteAllOperation() -> BaseOperation<Void> { operation(()) }
}

final class CovCPJCCObservable<T>: DataProviderRepositoryObservable {
    typealias Model = T

    func start(completionBlock: @escaping (Error?) -> Void) { completionBlock(nil) }
    func stop(completionBlock: @escaping (Error?) -> Void) { completionBlock(nil) }
    func addObserver(_: AnyObject, deliverOn _: DispatchQueue, executing _: @escaping ([DataProviderChange<T>]) -> Void) {}
    func removeObserver(_: AnyObject) {}
}

/// Subscription factory whose storage providers are unavailable, so subscriptions fail quietly.
final class CovCPJCCSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol {
    private(set) var poolMemberRequests: [AccountId] = []

    func getMinNominatorBondProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedBigUInt> {
        throw CovCPJTestError.failed
    }

    func getCounterForNominatorsProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> {
        throw CovCPJTestError.failed
    }

    func getMaxNominatorsCountProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> {
        throw CovCPJTestError.failed
    }

    func getNominationProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedNomination> {
        throw CovCPJTestError.failed
    }

    func getValidatorProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedValidator> {
        throw CovCPJTestError.failed
    }

    func getLedgerInfoProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedLedgerInfo> {
        throw CovCPJTestError.failed
    }

    func getActiveEra(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedActiveEra> {
        throw CovCPJTestError.failed
    }

    func getCurrentEra(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedEraIndex> {
        throw CovCPJTestError.failed
    }

    func getPayee(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedPayee> {
        throw CovCPJTestError.failed
    }

    func getTotalReward(
        for _: AccountAddress,
        chain _: ChainModel,
        assetPrecision _: Int16
    ) throws -> AnySingleValueProvider<TotalRewardItem> {
        throw CovCPJTestError.failed
    }

    func getStashItemProvider(for _: AccountAddress) -> StreamableProvider<StashItem> {
        StreamableProvider(
            source: AnyStreamableSource(EmptyStreamableSource<StashItem>()),
            repository: AnyDataProviderRepository(CovCPJCCRepository<StashItem>()),
            observable: AnyDataProviderRepositoryObservable(CovCPJCCObservable<StashItem>()),
            operationManager: CovCPJIntOperationManager()
        )
    }

    func getPoolMembersProvider(for _: ChainAsset, accountId: AccountId) throws -> AnyDataProvider<DecodedPoolMember> {
        poolMemberRequests.append(accountId)
        throw CovCPJTestError.failed
    }
}

final class CovCPJCCOutput: StakingPoolCreateConfirmInteractorOutput {
    let log = CovCPJIntEventLog()

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        if case let .success(info) = result { log.append("fee:\(info.fee)") } else { log.append("fee-error") }
    }

    func didReceive(extrinsicResult: SubmitExtrinsicResult) {
        if case let .success(hash) = extrinsicResult { log.append("submitted:\(hash)") } else { log.append("submit-error") }
    }

    func didReceive(stakingPoolMembers: Result<StakingPoolMember?, Error>) {
        switch stakingPoolMembers {
        case let .success(member): log.append("member:\(member.map { String($0.poolId.value) } ?? "nil")")
        case .failure: log.append("member-error")
        }
    }
}

final class CovCPJCreateConfirmInteractorTests: XCTestCase {
    private var subscriptionFactory: CovCPJCCSubscriptionFactory!
    private var feeProxy: CovCPJIntFeeProxy!
    private var extrinsicService: CovCPJIntExtrinsicService!
    private var root: fearless.MetaAccountModel!
    private var chainAsset: ChainAsset!

    override func setUp() {
        super.setUp()
        subscriptionFactory = CovCPJCCSubscriptionFactory()
        feeProxy = CovCPJIntFeeProxy()
        extrinsicService = CovCPJIntExtrinsicService()
        root = CovCPJFixtures.wallet()
        chainAsset = CovCPJFixtures.chainAsset(precision: 10)
    }

    override func tearDown() {
        subscriptionFactory = nil
        feeProxy = nil
        extrinsicService = nil
        root = nil
        chainAsset = nil
        super.tearDown()
    }

    private func makeInteractor(poolName: String = "Pool") -> StakingPoolCreateConfirmInteractor {
        let data = StakingPoolCreateData(
            poolId: 6,
            poolName: poolName,
            amount: 3,
            root: root,
            nominator: root,
            bouncer: root,
            chainAsset: chainAsset
        )

        return StakingPoolCreateConfirmInteractor(
            stakingLocalSubscriptionFactory: subscriptionFactory,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            createData: data,
            signingWrapper: CovCPJIntSigner(),
            callFactory: SubstrateCallFactoryDefault(runtimeService: CovCPJIntRuntimeProvider())
        )
    }

    func testSetupSubscribesToRootPoolMembership() throws {
        let interactor = makeInteractor()
        let output = CovCPJCCOutput()

        interactor.setup(with: output)

        let rootId = try XCTUnwrap(root.fetch(for: chainAsset.chain.accountRequest())?.accountId)
        XCTAssertTrue(feeProxy.delegate === interactor)
        XCTAssertEqual(subscriptionFactory.poolMemberRequests, [rootId])
    }

    func testFeeIsNotRequestedWithoutRuntimeMetadata() {
        let interactor = makeInteractor()
        let output = CovCPJCCOutput()
        interactor.setup(with: output)

        interactor.estimateFee()
        interactor.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 8)), for: "id")

        XCTAssertTrue(feeProxy.reuseIdentifiers.isEmpty)
        XCTAssertEqual(output.log.events, ["fee:8"])
    }

    func testSubmitForwardsExtrinsicResult() {
        let interactor = makeInteractor()
        let output = CovCPJCCOutput()
        interactor.setup(with: output)

        interactor.submit()
        extrinsicService.submitResult = .failure(CovCPJTestError.failed)
        interactor.submit()

        XCTAssertEqual(extrinsicService.submitCount, 2)
        XCTAssertEqual(output.log.events, ["submitted:0xfeed", "submit-error"])
    }

    func testSubmitWithNonAsciiNameIsSkipped() {
        let interactor = makeInteractor(poolName: "Pool \u{2713}")
        let output = CovCPJCCOutput()
        interactor.setup(with: output)

        interactor.submit()

        XCTAssertEqual(extrinsicService.submitCount, 0)
        XCTAssertTrue(output.log.events.isEmpty)
    }

    func testPoolMemberUpdatesAreDeliveredOnMain() throws {
        let interactor = makeInteractor()
        let output = CovCPJCCOutput()
        interactor.setup(with: output)

        interactor.handlePoolMember(
            result: .success(try CovCPJFixtures.poolMember(poolId: 6, points: "30")),
            accountId: Data(),
            chainId: chainAsset.chain.chainId
        )
        interactor.handlePoolMember(result: .failure(CovCPJTestError.failed), accountId: Data(), chainId: "id")
        CovCPJFixtures.spin { output.log.events.count == 2 }

        XCTAssertEqual(output.log.events, ["member:6", "member-error"])
    }
}
