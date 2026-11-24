import XCTest
import SSFModels
import RobinHood
import SSFRuntimeCodingService
import BigInt
import Web3
@testable import fearless

struct CovCPMMgmtIntError: Error {}

enum CovCPMMgmtIntWrap {
    static func wrapper<T>(_ result: Result<T, Error>) -> CompoundOperationWrapper<T> {
        let operation = BaseOperation<T>()
        operation.result = result
        return CompoundOperationWrapper(targetOperation: operation)
    }
}

final class CovCPMMgmtIntOutputSpy: StakingPoolManagementInteractorOutput {
    private(set) var stakeInfos: [StakingPoolMember?] = []
    private(set) var stakeInfoErrors: [Error] = []
    private(set) var eraStakers: [EraStakersInfo] = []
    private(set) var countdownResults: [Result<EraCountdown, Error>] = []
    private(set) var eraStakersErrors: [Error] = []
    private(set) var pools: [StakingPool?] = []
    private(set) var accountInfoResults: [Result<AccountInfo?, Error>] = []
    private(set) var errors: [Error] = []
    private(set) var durations: [StakingDuration] = []
    private(set) var poolRewards: [StakingPoolRewards?] = []
    private(set) var poolRewardsErrors: [Error] = []
    private(set) var poolAccountInfos: [AccountInfo?] = []
    private(set) var existentialDeposits: [Result<BigUInt, Error>] = []
    private(set) var palletResults: [Result<Data, Error>] = []
    private(set) var validatorResults: [Result<[ElectedValidatorInfo], Error>] = []
    private(set) var nominations: [Nomination?] = []
    private(set) var pendingRewards: [BigUInt?] = []
    private(set) var pendingRewardsErrors: [Error] = []

    func didReceive(stakeInfo: StakingPoolMember?) { stakeInfos.append(stakeInfo) }
    func didReceive(stakeInfoError: Error) { stakeInfoErrors.append(stakeInfoError) }
    func didReceive(eraStakersInfo: EraStakersInfo) { eraStakers.append(eraStakersInfo) }
    func didReceive(eraCountdownResult: Result<EraCountdown, Error>) { countdownResults.append(eraCountdownResult) }
    func didReceive(eraStakersInfoError: Error) { eraStakersErrors.append(eraStakersInfoError) }
    func didReceive(stakingPool: StakingPool?) { pools.append(stakingPool) }
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) { accountInfoResults.append(result) }
    func didReceive(error: Error) { errors.append(error) }
    func didReceive(stakingDuration: StakingDuration) { durations.append(stakingDuration) }
    func didReceive(poolRewards: StakingPoolRewards?) { self.poolRewards.append(poolRewards) }
    func didReceive(poolRewardsError: Error) { poolRewardsErrors.append(poolRewardsError) }
    func didReceive(poolAccountInfo: AccountInfo?) { poolAccountInfos.append(poolAccountInfo) }
    func didReceive(existentialDepositResult: Result<BigUInt, Error>) { existentialDeposits.append(existentialDepositResult) }
    func didReceive(palletIdResult: Result<Data, Error>) { palletResults.append(palletIdResult) }
    func didReceiveValidators(result: Result<[ElectedValidatorInfo], Error>) { validatorResults.append(result) }
    func didReceive(nomination: Nomination?) { nominations.append(nomination) }
    func didReceive(pendingRewards: BigUInt?) { self.pendingRewards.append(pendingRewards) }
    func didReceive(pendingRewardsError: Error) { pendingRewardsErrors.append(pendingRewardsError) }
}

final class CovCPMMgmtIntRuntimeStub: RuntimeCodingServiceProtocol {
    var snapshot: RuntimeSnapshot? { nil }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        let operation = BaseOperation<RuntimeCoderFactoryProtocol>()
        operation.result = .failure(CovCPMMgmtIntError())
        return operation
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol { throw CovCPMMgmtIntError() }
}

final class CovCPMMgmtIntValidatorFactoryStub: ValidatorOperationFactoryProtocol {
    var nominationResult: Result<Nomination?, Error> = .success(nil)
    var electedResult: Result<[ElectedValidatorInfo], Error> = .success([])

    func nomination(accountId _: AccountId) -> CompoundOperationWrapper<Nomination?> { CovCPMMgmtIntWrap.wrapper(nominationResult) }
    func fetchAllValidators() -> CompoundOperationWrapper<[ElectedValidatorInfo]> { CovCPMMgmtIntWrap.wrapper(.success([])) }
    func allElectedOperation() -> CompoundOperationWrapper<[ElectedValidatorInfo]> { CovCPMMgmtIntWrap.wrapper(electedResult) }
    func allSelectedOperation(by _: Nomination, nominatorAddress _: AccountAddress) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        CovCPMMgmtIntWrap.wrapper(.success([]))
    }

    func activeValidatorsOperation(for _: AccountAddress) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        CovCPMMgmtIntWrap.wrapper(.success([]))
    }

    func pendingValidatorsOperation(for _: [AccountId]) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        CovCPMMgmtIntWrap.wrapper(.success([]))
    }

    func wannabeValidatorsOperation(for _: [AccountId]) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        CovCPMMgmtIntWrap.wrapper(.success([]))
    }
}

final class CovCPMMgmtIntPoolFactoryStub: StakingPoolOperationFactoryProtocol {
    var bondedPoolResult: Result<StakingPool?, Error> = .success(nil)
    var rewardsResult: Result<StakingPoolRewards?, Error> = .success(nil)
    var pendingRewardsResult: Result<BigUInt?, Error> = .success(BigUInt(7))
    private(set) var requestedPoolIds: [String] = []
    private(set) var requestedRewardPoolIds: [String] = []

    func fetchBondedPoolsOperation() -> CompoundOperationWrapper<[StakingPool]> { CovCPMMgmtIntWrap.wrapper(.success([])) }
    func fetchPoolMetadataOperation(poolId _: String) -> CompoundOperationWrapper<String?> { CovCPMMgmtIntWrap.wrapper(.success(nil)) }
    func fetchMinJoinBondOperation() -> CompoundOperationWrapper<BigUInt?> { CovCPMMgmtIntWrap.wrapper(.success(nil)) }
    func fetchMinCreateBondOperation() -> CompoundOperationWrapper<BigUInt?> { CovCPMMgmtIntWrap.wrapper(.success(nil)) }
    func fetchStakingPoolMembers(accountId _: AccountId) -> CompoundOperationWrapper<StakingPoolMember?> {
        CovCPMMgmtIntWrap.wrapper(.success(nil))
    }

    func fetchMaxStakingPoolsCount() -> CompoundOperationWrapper<UInt32?> { CovCPMMgmtIntWrap.wrapper(.success(nil)) }
    func fetchMaxPoolMembers() -> CompoundOperationWrapper<UInt32?> { CovCPMMgmtIntWrap.wrapper(.success(nil)) }
    func fetchCounterForBondedPools() -> CompoundOperationWrapper<UInt32?> { CovCPMMgmtIntWrap.wrapper(.success(nil)) }
    func fetchMaxPoolMembersPerPool() -> CompoundOperationWrapper<UInt32?> { CovCPMMgmtIntWrap.wrapper(.success(nil)) }

    func fetchBondedPoolOperation(poolId: String) -> CompoundOperationWrapper<StakingPool?> {
        requestedPoolIds.append(poolId)
        return CovCPMMgmtIntWrap.wrapper(bondedPoolResult)
    }

    func fetchPoolRewardsOperation(poolId: String) -> CompoundOperationWrapper<StakingPoolRewards?> {
        requestedRewardPoolIds.append(poolId)
        return CovCPMMgmtIntWrap.wrapper(rewardsResult)
    }

    func fetchLastPoolId() -> CompoundOperationWrapper<UInt32?> { CovCPMMgmtIntWrap.wrapper(.success(nil)) }
    func fetchPendingRewards(accountId _: AccountId) -> CompoundOperationWrapper<BigUInt?> { CovCPMMgmtIntWrap.wrapper(pendingRewardsResult) }
}

final class CovCPMMgmtIntSubscriptionFactoryStub: RelaychainStakingLocalSubscriptionFactoryProtocol {
    private(set) var poolMemberRequests = 0

    func getMinNominatorBondProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedBigUInt> { throw CovCPMMgmtIntError() }
    func getCounterForNominatorsProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> { throw CovCPMMgmtIntError() }
    func getMaxNominatorsCountProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> { throw CovCPMMgmtIntError() }
    func getNominationProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedNomination> {
        throw CovCPMMgmtIntError()
    }

    func getValidatorProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedValidator> {
        throw CovCPMMgmtIntError()
    }

    func getLedgerInfoProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedLedgerInfo> {
        throw CovCPMMgmtIntError()
    }

    func getActiveEra(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedActiveEra> { throw CovCPMMgmtIntError() }
    func getCurrentEra(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedEraIndex> { throw CovCPMMgmtIntError() }
    func getPayee(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedPayee> { throw CovCPMMgmtIntError() }

    func getTotalReward(for _: AccountAddress, chain _: ChainModel, assetPrecision _: Int16) throws -> AnySingleValueProvider<TotalRewardItem> {
        throw CovCPMMgmtIntError()
    }

    func getStashItemProvider(for address: AccountAddress) -> StreamableProvider<StashItem> {
        SubstrateDataProviderFactory(facade: SubstrateDataStorageFacade.shared, operationManager: OperationManager())
            .createStashItemProvider(for: address)
    }

    func getPoolMembersProvider(for _: ChainAsset, accountId _: AccountId) throws -> AnyDataProvider<DecodedPoolMember> {
        poolMemberRequests += 1
        throw CovCPMMgmtIntError()
    }
}

final class CovCPMMgmtIntEraServiceStub: EraValidatorServiceProtocol {
    var infoResult: Result<EraStakersInfo, Error> = .success(EraStakersInfo(activeEra: 6, validators: []))

    func setup() {}
    func throttle() {}

    func fetchInfoOperation() -> BaseOperation<EraStakersInfo> {
        let operation = BaseOperation<EraStakersInfo>()
        operation.result = infoResult
        return operation
    }
}

final class CovCPMMgmtIntChainRegistryStub: ChainRegistryProtocol {
    var availableChainIds: Set<ChainModel.Id>? { nil }
    var availableChains: [ChainModel] { [] }
    var chainsTypesMap: [String: Data] { [:] }

    func resetConnection(for _: ChainModel.Id) {}
    func retryConnection(for _: ChainModel.Id) {}
    func getConnection(for _: ChainModel.Id) -> ChainConnection? { nil }
    func getEthereumConnection(for _: ChainModel.Id) -> Web3.Eth? { nil }
    func getTonApiClientFactory() throws -> TonAPIClientFactory { throw CovCPMMgmtIntError() }
    func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? { nil }
    func getChain(for _: ChainModel.Id) -> ChainModel? { nil }
    func chainsSubscribe(_: AnyObject, runningInQueue _: DispatchQueue, updateClosure _: @escaping ([DataProviderChange<ChainModel>]) -> Void) {}
    func chainsUnsubscribe(_: AnyObject) {}
    func syncUp() {}
    func performHotBoot() {}
    func performColdBoot() {}
    func subscribeToChains() {}
}

final class CovCPMMgmtIntCountdownFactoryStub: EraCountdownOperationFactoryProtocol {
    func fetchCountdownOperationWrapper(for _: ChainConnection, runtimeService _: RuntimeCodingServiceProtocol) -> CompoundOperationWrapper<EraCountdown> {
        CovCPMMgmtIntWrap.wrapper(.failure(CovCPMMgmtIntError()))
    }
}

final class CovCPMMgmtIntWalletSubscriptionFactoryStub: WalletLocalSubscriptionFactoryProtocol {
    let operationManager: OperationManagerProtocol = OperationManager()
    var processingQueue: DispatchQueue? { nil }

    func getAccountProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> StreamableProvider<AccountInfoStorageWrapper> {
        throw CovCPMMgmtIntError()
    }

    func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? { nil }
}

final class CovCPMMgmtIntDurationFactoryStub: StakingDurationOperationFactoryProtocol {
    var result: Result<StakingDuration, Error> = .success(StakingDuration(session: 10, era: 60, unlocking: 600))

    func createDurationOperation(from _: RuntimeCodingServiceProtocol) -> CompoundOperationWrapper<StakingDuration> {
        CovCPMMgmtIntWrap.wrapper(result)
    }
}

final class CovCPMMgmtIntAccountFactoryStub: AccountOperationFactoryProtocol {
    var accountInfoResult: Result<AccountInfo?, Error> = .success(nil)
    private(set) var requestedAccounts: [Data] = []

    func createGenisisHashOperation() -> BaseOperation<String> { BaseOperation<String>() }
    func createBlockHashOperation(_: UInt32) -> BaseOperation<String> { BaseOperation<String>() }
    func createAccountInfoFetchOperation(_ accountId: Data) -> CompoundOperationWrapper<AccountInfo?> {
        requestedAccounts.append(accountId)
        return CovCPMMgmtIntWrap.wrapper(accountInfoResult)
    }
}

final class CovCPMMgmtIntExistentialDepositStub: ExistentialDepositServiceProtocol {
    var result: Result<BigUInt, Error> = .success(BigUInt(100))

    func fetchExistentialDeposit(chainAsset _: ChainAsset, completion: @escaping (Result<BigUInt, Error>) -> Void) {
        completion(result)
    }
}

final class CovCPMPoolManagementInteractorTests: XCTestCase {
    private var chainAsset: ChainAsset!
    private var poolFactory: CovCPMMgmtIntPoolFactoryStub!
    private var validatorFactory: CovCPMMgmtIntValidatorFactoryStub!
    private var subscriptionFactory: CovCPMMgmtIntSubscriptionFactoryStub!
    private var eraService: CovCPMMgmtIntEraServiceStub!
    private var durationFactory: CovCPMMgmtIntDurationFactoryStub!
    private var accountFactory: CovCPMMgmtIntAccountFactoryStub!
    private var existentialDeposit: CovCPMMgmtIntExistentialDepositStub!
    private var output: CovCPMMgmtIntOutputSpy!

    override func setUp() {
        super.setUp()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        chainAsset = ChainAsset(chain: chain, asset: asset)
        poolFactory = CovCPMMgmtIntPoolFactoryStub()
        validatorFactory = CovCPMMgmtIntValidatorFactoryStub()
        subscriptionFactory = CovCPMMgmtIntSubscriptionFactoryStub()
        eraService = CovCPMMgmtIntEraServiceStub()
        durationFactory = CovCPMMgmtIntDurationFactoryStub()
        accountFactory = CovCPMMgmtIntAccountFactoryStub()
        existentialDeposit = CovCPMMgmtIntExistentialDepositStub()
        output = CovCPMMgmtIntOutputSpy()
    }

    override func tearDown() {
        chainAsset = nil
        poolFactory = nil
        validatorFactory = nil
        subscriptionFactory = nil
        eraService = nil
        durationFactory = nil
        accountFactory = nil
        existentialDeposit = nil
        output = nil
        super.tearDown()
    }

    private func makeInteractor(wallet: fearless.MetaAccountModel = AccountGenerator.generateMetaAccount()) -> StakingPoolManagementInteractor {
        StakingPoolManagementInteractor(
            stakingPoolOperationFactory: poolFactory,
            chainAsset: chainAsset,
            wallet: wallet,
            eraValidatorService: eraService,
            operationManager: OperationManager(),
            chainRegistry: CovCPMMgmtIntChainRegistryStub(),
            eraCountdownOperationFactory: CovCPMMgmtIntCountdownFactoryStub(),
            stakingLocalSubscriptionFactory: subscriptionFactory,
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: CovCPMMgmtIntWalletSubscriptionFactoryStub(),
                selectedMetaAccount: wallet
            ),
            stakingDurationOperationFactory: durationFactory,
            runtimeService: CovCPMMgmtIntRuntimeStub(),
            accountOperationFactory: accountFactory,
            existentialDepositService: existentialDeposit,
            validatorOperationFactory: validatorFactory
        )
    }

    private func walletWithoutSubstrateAccount() -> fearless.MetaAccountModel {
        fearless.MetaAccountModel(
            metaId: UUID().uuidString,
            name: "empty",
            substrateAccountId: nil,
            substrateCryptoType: 0,
            substratePublicKey: nil,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [],
            assetKeysOrder: nil,
            canExportEthereumMnemonic: false,
            unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(),
            networkManagmentFilter: nil,
            assetsVisibility: [],
            hasBackup: false,
            favouriteChainIds: []
        )
    }

    private func spin(until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    private func member(poolId: UInt32) throws -> StakingPoolMember {
        let json: [String: Any] = ["poolId": "\(poolId)", "points": "10", "lastRecordedRewardCounter": "0", "unbondingEras": []]
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(StakingPoolMember.self, from: data)
    }

    func testSetupFetchesAllInitialData() {
        let interactor = makeInteractor()

        interactor.setup(with: output)
        spin {
            !output.palletResults.isEmpty && !output.validatorResults.isEmpty && !output.countdownResults.isEmpty
                && !output.durations.isEmpty && !output.pendingRewards.isEmpty
        }

        XCTAssertEqual(subscriptionFactory.poolMemberRequests, 1)
        XCTAssertEqual(output.existentialDeposits.count, 1)
        guard case .failure? = output.palletResults.first, case .success? = output.validatorResults.first else {
            return XCTFail("unexpected pallet or validators result")
        }
        XCTAssertEqual(output.eraStakers.first?.activeEra, 6)
        guard case .failure? = output.countdownResults.first else {
            return XCTFail("expected countdown failure without runtime provider")
        }
        XCTAssertEqual(output.durations.first?.era, 60)
        XCTAssertEqual(output.pendingRewards.first ?? nil, BigUInt(7))
    }

    func testSetupFailuresAreReported() {
        validatorFactory.electedResult = .failure(CovCPMMgmtIntError())
        eraService.infoResult = .failure(CovCPMMgmtIntError())
        durationFactory.result = .failure(CovCPMMgmtIntError())
        poolFactory.pendingRewardsResult = .failure(CovCPMMgmtIntError())
        existentialDeposit.result = .failure(CovCPMMgmtIntError())
        let interactor = makeInteractor()

        interactor.setup(with: output)
        spin {
            !output.validatorResults.isEmpty && !output.eraStakersErrors.isEmpty && !output.errors.isEmpty
                && !output.pendingRewardsErrors.isEmpty
        }

        guard case .failure? = output.validatorResults.first, case .failure? = output.existentialDeposits.first else {
            return XCTFail("expected failures")
        }
        XCTAssertEqual(output.eraStakersErrors.count, 1)
        XCTAssertEqual(output.errors.count, 1)
        XCTAssertEqual(output.pendingRewardsErrors.count, 1)
        XCTAssertTrue(output.countdownResults.isEmpty)
    }

    func testSetupWithoutAccountSkipsAccountBoundRequests() {
        let interactor = makeInteractor(wallet: walletWithoutSubstrateAccount())

        interactor.setup(with: output)
        spin { !output.palletResults.isEmpty && !output.durations.isEmpty }

        XCTAssertEqual(subscriptionFactory.poolMemberRequests, 0)
        XCTAssertTrue(output.pendingRewards.isEmpty)
        XCTAssertEqual(output.existentialDeposits.count, 1)
    }

    func testFetchPoolBalanceDeliversAccountInfo() {
        let info = AccountInfo(nonce: 0, consumers: 0, providers: 0, data: AccountData(free: 5, reserved: 0, frozen: 0))
        accountFactory.accountInfoResult = .success(info)
        let interactor = makeInteractor()
        interactor.setup(with: output)
        let accountId = Data(repeating: 8, count: 32)

        interactor.fetchPoolBalance(poolAccountId: accountId)
        spin { !output.poolAccountInfos.isEmpty }

        XCTAssertEqual(accountFactory.requestedAccounts, [accountId])
        XCTAssertEqual(output.poolAccountInfos.first ?? nil, info)
    }

    func testFetchPoolNominationSuccessAndFailure() throws {
        let interactor = makeInteractor()
        interactor.setup(with: output)
        spin { !output.durations.isEmpty }

        interactor.fetchPoolNomination(poolStashAccountId: Data(repeating: 1, count: 32))
        spin { !output.nominations.isEmpty }
        XCTAssertEqual(output.nominations.count, 1)
        XCTAssertNil(output.nominations.first ?? nil)

        validatorFactory.nominationResult = .failure(CovCPMMgmtIntError())
        interactor.fetchPoolNomination(poolStashAccountId: Data(repeating: 1, count: 32))
        spin { !output.errors.isEmpty }
        XCTAssertEqual(output.errors.count, 1)
    }

    func testPoolMemberHandlerFetchesPoolAndRewards() throws {
        let pool = StakingPool(
            id: "21",
            info: StakingPoolInfo(points: 1, state: .open, memberCounter: 1, roles: StakingPoolRoles(depositor: Data(repeating: 2, count: 32))),
            name: "Pool 21"
        )
        poolFactory.bondedPoolResult = .success(pool)
        poolFactory.rewardsResult = .failure(CovCPMMgmtIntError())
        let interactor = makeInteractor()
        interactor.setup(with: output)

        interactor.handlePoolMember(result: .success(try member(poolId: 21)), accountId: Data(), chainId: chainAsset.chain.chainId)
        spin { !output.stakeInfos.isEmpty && !output.pools.isEmpty && !output.poolRewardsErrors.isEmpty }

        XCTAssertEqual(poolFactory.requestedPoolIds, ["21"])
        XCTAssertEqual(poolFactory.requestedRewardPoolIds, ["21"])
        XCTAssertEqual(output.stakeInfos.first??.poolId.value, 21)
        XCTAssertEqual(output.pools.first??.name, "Pool 21")
        XCTAssertEqual(output.poolRewardsErrors.count, 1)
    }

    func testPoolMemberHandlerWithoutMemberAndFailure() {
        poolFactory.rewardsResult = .success(nil)
        let interactor = makeInteractor()
        interactor.setup(with: output)

        interactor.handlePoolMember(result: .success(nil), accountId: Data(), chainId: chainAsset.chain.chainId)
        interactor.handlePoolMember(result: .failure(CovCPMMgmtIntError()), accountId: Data(), chainId: chainAsset.chain.chainId)
        spin { !output.stakeInfos.isEmpty && !output.stakeInfoErrors.isEmpty }

        XCTAssertNil(output.stakeInfos.first ?? nil)
        XCTAssertEqual(output.stakeInfoErrors.count, 1)
        XCTAssertTrue(poolFactory.requestedPoolIds.isEmpty)
    }

    func testAccountInfoHandlerForwardsResult() {
        let interactor = makeInteractor()
        interactor.setup(with: output)

        interactor.handleAccountInfo(result: .success(nil), accountId: Data(), chainAsset: chainAsset)

        XCTAssertEqual(output.accountInfoResults.count, 1)
    }
}
