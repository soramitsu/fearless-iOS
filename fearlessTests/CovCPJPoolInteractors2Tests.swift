import XCTest
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import BigInt
@testable import fearless

final class CovCPJIntValidatorFactory: ValidatorOperationFactoryProtocol {
    var nominationResult: Result<Nomination?, Error> = .success(nil)
    private(set) var nominationRequests: [AccountId] = []

    func nomination(accountId: AccountId) -> CompoundOperationWrapper<Nomination?> {
        nominationRequests.append(accountId)
        return CovCPJIntWrappers.wrapper(nominationResult)
    }

    func fetchAllValidators() -> CompoundOperationWrapper<[ElectedValidatorInfo]> {
        CovCPJIntWrappers.wrapper(.success([]))
    }

    func allElectedOperation() -> CompoundOperationWrapper<[ElectedValidatorInfo]> {
        CovCPJIntWrappers.wrapper(.success([]))
    }

    func allSelectedOperation(by _: Nomination, nominatorAddress _: AccountAddress) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        CovCPJIntWrappers.wrapper(.success([]))
    }

    func activeValidatorsOperation(for _: AccountAddress) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        CovCPJIntWrappers.wrapper(.success([]))
    }

    func pendingValidatorsOperation(for _: [AccountId]) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        CovCPJIntWrappers.wrapper(.success([]))
    }

    func wannabeValidatorsOperation(for _: [AccountId]) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        CovCPJIntWrappers.wrapper(.success([]))
    }
}

final class CovCPJIntAccountRepository: DataProviderRepositoryProtocol {
    typealias Model = fearless.MetaAccountModel

    var accounts: Result<[fearless.MetaAccountModel], Error> = .success([])

    private func operation<T>(_ result: Result<T, Error>) -> BaseOperation<T> {
        let operation = BaseOperation<T>()
        operation.result = result
        return operation
    }

    func fetchOperation(by _: @escaping () throws -> [String], options _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        operation(accounts)
    }

    func fetchOperation(by _: @escaping () throws -> String, options _: RepositoryFetchOptions) -> BaseOperation<Model?> {
        operation(.success(nil))
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        operation(accounts)
    }

    func fetchOperation(by _: RepositorySliceRequest, options _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        operation(accounts)
    }

    func saveOperation(_: @escaping () throws -> [Model], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        operation(.success(()))
    }

    func saveBatchOperation(_: @escaping () throws -> [Model], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        operation(.success(()))
    }

    func replaceOperation(_: @escaping () throws -> [Model]) -> BaseOperation<Void> {
        operation(.success(()))
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        operation(.success(0))
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        operation(.success(()))
    }
}

final class CovCPJIntRewardService: RewardCalculatorServiceProtocol {
    var calculatorResult: Result<RewardCalculatorEngineProtocol, Error> = .failure(CovCPJTestError.failed)
    private(set) var setupCount = 0

    func setup() { setupCount += 1 }
    func throttle() {}

    func fetchCalculatorOperation() -> BaseOperation<RewardCalculatorEngineProtocol> {
        let operation = BaseOperation<RewardCalculatorEngineProtocol>()
        operation.result = calculatorResult
        return operation
    }
}

final class CovCPJIntDurationFactory: StakingDurationOperationFactoryProtocol {
    var result: Result<StakingDuration, Error> = .failure(CovCPJTestError.failed)

    func createDurationOperation(from _: RuntimeCodingServiceProtocol) -> CompoundOperationWrapper<StakingDuration> {
        CovCPJIntWrappers.wrapper(result)
    }
}

final class CovCPJIntJoinConfirmOutput: StakingPoolJoinConfirmInteractorOutput {
    let log = CovCPJIntEventLog()

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        if case let .success(info) = result { log.append("fee:\(info.fee)") } else { log.append("fee-error") }
    }

    func didReceive(extrinsicResult: SubmitExtrinsicResult) {
        if case let .success(hash) = extrinsicResult { log.append("submitted:\(hash)") } else { log.append("submit-error") }
    }

    func didReceive(palletIdResult: Result<Data, Error>) {
        if case .success = palletIdResult { log.append("pallet") } else { log.append("pallet-error") }
    }

    func didReceive(nomination: Nomination?) { log.append("nomination:\(nomination?.targets.count ?? -1)") }
    func didReceive(error _: Error) { log.append("error") }
}

final class CovCPJIntRolesOutput: PoolRolesConfirmInteractorOutput {
    let log = CovCPJIntEventLog()

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        if case let .success(info) = result { log.append("fee:\(info.fee)") } else { log.append("fee-error") }
    }

    func didReceive(extrinsicResult: SubmitExtrinsicResult) {
        if case let .success(hash) = extrinsicResult { log.append("submitted:\(hash)") } else { log.append("submit-error") }
    }

    func didReceive(accounts: [fearless.MetaAccountModel]) { log.append("accounts:\(accounts.count)") }
    func didReceive(error _: Error) { log.append("error") }
}

final class CovCPJIntStartOutput: StakingPoolStartInteractorOutput {
    let log = CovCPJIntEventLog()
    private(set) var networkInfo: StakingPoolNetworkInfo?

    func didReceive(stakingDuration: StakingDuration) { log.append("duration:\(Int(stakingDuration.era))") }
    func didReceive(error _: Error) { log.append("error") }
    func didReceive(calculator _: RewardCalculatorEngineProtocol) { log.append("calculator") }
    func didReceive(calculatorError _: Error) { log.append("calculator-error") }

    func didReceive(networkInfo: StakingPoolNetworkInfo) {
        self.networkInfo = networkInfo
        log.append("network")
    }
}

final class CovCPJPoolInteractors2Tests: XCTestCase {
    private var chainAsset: ChainAsset!
    private var feeProxy: CovCPJIntFeeProxy!
    private var extrinsicService: CovCPJIntExtrinsicService!
    private var operationManager: CovCPJIntOperationManager!
    private var callFactory: SubstrateCallFactoryDefault!

    override func setUp() {
        super.setUp()
        chainAsset = CovCPJFixtures.chainAsset(precision: 10)
        feeProxy = CovCPJIntFeeProxy()
        extrinsicService = CovCPJIntExtrinsicService()
        operationManager = CovCPJIntOperationManager()
        callFactory = SubstrateCallFactoryDefault(runtimeService: CovCPJIntRuntimeProvider())
    }

    override func tearDown() {
        chainAsset = nil
        feeProxy = nil
        extrinsicService = nil
        operationManager = nil
        callFactory = nil
        super.tearDown()
    }

    // MARK: - Join confirm

    private func makeJoinConfirmInteractor(validators: CovCPJIntValidatorFactory) -> StakingPoolJoinConfirmInteractor {
        StakingPoolJoinConfirmInteractor(
            chainAsset: chainAsset,
            wallet: CovCPJFixtures.wallet(),
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            amount: 2,
            pool: CovCPJFixtures.pool(id: "8", name: "Pool", points: 1, members: 1),
            signingWrapper: CovCPJIntSigner(),
            runtimeService: CovCPJIntRuntimeProvider(),
            operationManager: operationManager,
            validatorOperationFactory: validators,
            callFactory: callFactory
        )
    }

    func testJoinConfirmSetupReportsMissingPalletIdAndEstimatesFee() {
        let interactor = makeJoinConfirmInteractor(validators: CovCPJIntValidatorFactory())
        let output = CovCPJIntJoinConfirmOutput()

        interactor.setup(with: output)
        interactor.estimateFee()
        interactor.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 4)), for: "id")
        CovCPJFixtures.spin { output.log.contains("pallet-error") }

        XCTAssertTrue(feeProxy.delegate === interactor)
        XCTAssertTrue(output.log.contains("pallet-error"))
        XCTAssertEqual(feeProxy.reuseIdentifiers, [callFactory.joinPool(poolId: "8", amount: 1).callName])
        XCTAssertTrue(output.log.contains("fee:4"))
    }

    func testJoinConfirmSubmitForwardsResult() {
        let interactor = makeJoinConfirmInteractor(validators: CovCPJIntValidatorFactory())
        let output = CovCPJIntJoinConfirmOutput()
        interactor.setup(with: output)

        interactor.submit()
        extrinsicService.submitResult = .failure(CovCPJTestError.failed)
        interactor.submit()

        XCTAssertEqual(extrinsicService.submitCount, 2)
        XCTAssertTrue(output.log.contains("submitted:0xfeed"))
        XCTAssertTrue(output.log.contains("submit-error"))
    }

    func testJoinConfirmFetchesPoolNomination() throws {
        let validators = CovCPJIntValidatorFactory()
        validators.nominationResult = .success(try CovCPJFixtures.nomination(targetCount: 2))
        let interactor = makeJoinConfirmInteractor(validators: validators)
        let output = CovCPJIntJoinConfirmOutput()
        interactor.setup(with: output)
        let stash = Data(repeating: 7, count: 32)

        interactor.fetchPoolNomination(poolStashAccountId: stash)
        CovCPJFixtures.spin { output.log.contains("nomination:2") }

        XCTAssertEqual(validators.nominationRequests, [stash])
        XCTAssertTrue(output.log.contains("nomination:2"))
    }

    func testJoinConfirmNominationFailureReportsError() {
        let validators = CovCPJIntValidatorFactory()
        validators.nominationResult = .failure(CovCPJTestError.failed)
        let interactor = makeJoinConfirmInteractor(validators: validators)
        let output = CovCPJIntJoinConfirmOutput()
        interactor.setup(with: output)

        interactor.fetchPoolNomination(poolStashAccountId: Data(repeating: 1, count: 32))
        CovCPJFixtures.spin { output.log.contains("error") }

        XCTAssertTrue(output.log.contains("error"))
    }

    // MARK: - Pool roles

    private func makeRolesInteractor(repository: CovCPJIntAccountRepository) -> PoolRolesConfirmInteractor {
        PoolRolesConfirmInteractor(
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            poolId: "4",
            roles: CovCPJFixtures.roles(root: Data(repeating: 2, count: 32)),
            signingWrapper: CovCPJIntSigner(),
            chainAsset: chainAsset,
            accountRepository: AnyDataProviderRepository(repository),
            operationManager: operationManager,
            callFactory: callFactory
        )
    }

    func testRolesSetupLoadsAccountsAndEstimatesFee() {
        let repository = CovCPJIntAccountRepository()
        repository.accounts = .success([CovCPJFixtures.wallet(), CovCPJFixtures.wallet()])
        let interactor = makeRolesInteractor(repository: repository)
        let output = CovCPJIntRolesOutput()

        interactor.setup(with: output)
        interactor.estimateFee()
        interactor.didReceiveFee(result: .failure(CovCPJTestError.failed), for: "id")
        CovCPJFixtures.spin { output.log.contains("accounts:2") }

        XCTAssertTrue(feeProxy.delegate === interactor)
        XCTAssertTrue(output.log.contains("accounts:2"))
        XCTAssertEqual(feeProxy.reuseIdentifiers, [CallCodingPath.nominationPoolUpdateRoles.callName])
        XCTAssertTrue(output.log.contains("fee-error"))
    }

    func testRolesAccountFailureAndSubmit() {
        let repository = CovCPJIntAccountRepository()
        repository.accounts = .failure(CovCPJTestError.failed)
        let interactor = makeRolesInteractor(repository: repository)
        let output = CovCPJIntRolesOutput()

        interactor.setup(with: output)
        interactor.submit()
        CovCPJFixtures.spin { output.log.contains("error") }

        XCTAssertTrue(output.log.contains("error"))
        XCTAssertTrue(output.log.contains("submitted:0xfeed"))
        XCTAssertEqual(extrinsicService.submitCount, 1)
    }

    // MARK: - Start

    func testStartSetupDeliversCalculatorDurationAndNetworkInfo() throws {
        let rewardService = CovCPJIntRewardService()
        rewardService.calculatorResult = .success(CovCPJStartCalculatorStub(returnValue: 0.1))
        let durationFactory = CovCPJIntDurationFactory()
        durationFactory.result = .success(StakingDuration(session: 3600, era: 86400, unlocking: 604_800))
        let poolFactory = CovCPJIntPoolOperationFactory()
        poolFactory.minJoinBond = 1
        poolFactory.minCreateBond = 2
        poolFactory.maxPoolsCount = 10
        poolFactory.maxPoolMembers = 100
        poolFactory.bondedPoolsCounter = 3
        poolFactory.maxMembersPerPool = 20
        let interactor = StakingPoolStartInteractor(
            operationManager: operationManager,
            runtimeService: CovCPJIntRuntimeProvider(),
            stakingDurationOperationFactory: durationFactory,
            rewardService: rewardService,
            stakingPoolOperationFactory: poolFactory
        )
        let output = CovCPJIntStartOutput()

        interactor.setup(with: output)
        CovCPJFixtures.spin {
            output.log.contains("calculator") && output.log.contains("duration:86400") && output.log.contains("network")
        }

        XCTAssertEqual(rewardService.setupCount, 1)
        XCTAssertTrue(output.log.contains("calculator"))
        XCTAssertTrue(output.log.contains("duration:86400"))
        let info = try XCTUnwrap(output.networkInfo)
        XCTAssertEqual(info.minJoinBond, 1)
        XCTAssertEqual(info.minCreateBond, 2)
        XCTAssertEqual(info.existingPoolsCount, 3)
        XCTAssertEqual(info.possiblePoolsCount, 10)
        XCTAssertEqual(info.maxMembersInPool, 20)
        XCTAssertEqual(info.maxPoolsMembers, 100)
    }

    func testStartSetupReportsFailures() {
        let interactor = StakingPoolStartInteractor(
            operationManager: operationManager,
            runtimeService: CovCPJIntRuntimeProvider(),
            stakingDurationOperationFactory: CovCPJIntDurationFactory(),
            rewardService: CovCPJIntRewardService(),
            stakingPoolOperationFactory: CovCPJIntPoolOperationFactory()
        )
        let output = CovCPJIntStartOutput()

        interactor.setup(with: output)
        CovCPJFixtures.spin {
            output.log.contains("calculator-error") && output.log.contains("error") && output.log.contains("network")
        }

        XCTAssertTrue(output.log.contains("calculator-error"))
        XCTAssertTrue(output.log.contains("error"))
        XCTAssertNil(output.networkInfo?.existingPoolsCount)
    }
}
