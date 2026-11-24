import XCTest
import BigInt
import CoreData
import RobinHood
import SSFModels
import SSFRuntimeCodingService
#if canImport(SSFAssetManagmentStorage)
    import SSFAssetManagmentStorage
#endif
@testable import fearless

final class CovHSendInteractorFixture {
    let chainAsset: ChainAsset
    let wallet = AccountGenerator.generateMetaAccount()
    let output = CovHSendInteractorOutputSpy()
    let adapter = CovHSendAccountInfoAdapter()
    let remote = CovHSendRemoteService()
    let service = CovHSendTransferService()
    let existentialDeposit = CovHSendExistentialDeposit()
    let accountInfoFetching = CovHSendAccountInfoFetching()
    let scam = CovHSendScamFetching()
    let chainAssetFetching = CovHSendChainAssetFetching()
    let equilibrium = CovHSendEquilibriumService()
    let interactor: SendInteractor

    init(chainAsset: ChainAsset, runtime: Bool = true) {
        self.chainAsset = chainAsset
        let wallet = wallet
        let dependencies = SendDependencies(
            wallet: wallet,
            chainAsset: chainAsset,
            runtimeService: runtime ? CovHSendRuntimeService() : nil,
            existentialDepositService: existentialDeposit,
            equilibruimTotalBalanceService: equilibrium,
            transferService: service,
            accountInfoFetching: accountInfoFetching,
            polkaswapService: nil,
            storageRequestPerformer: nil
        )
        let chainRepository = ChainRepositoryFactory().createRepository(
            for: NSPredicate.enabledCHain(),
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let runtimeRepository: AsyncCoreDataRepositoryDefault<fearless.RuntimeMetadataItem, SSFAssetManagmentStorage.CDRuntimeMetadataItem> =
            SubstrateDataStorageFacade.shared.createAsyncRepository()
        interactor = SendInteractor(
            accountInfoSubscriptionAdapter: adapter,
            operationManager: OperationManager(),
            scamInfoFetching: scam,
            chainAssetFetching: chainAssetFetching,
            dependencyContainer: SendDepencyContainer(wallet: wallet, operationManager: OperationManager()),
            addressChainDefiner: AddressChainDefiner(
                operationManager: OperationManager(),
                chainModelRepository: AnyDataProviderRepository(chainRepository),
                wallet: wallet
            ),
            runtimeItemRepository: AsyncAnyRepository(runtimeRepository),
            accountInfoRemoteService: remote,
            prepareDependencies: { _ in dependencies }
        )
        interactor.setup(with: output)
    }
}

final class CovHSendInteractorOutputSpy: SendInteractorOutput {
    struct CovHSendInfo {
        let asset: ChainAsset
        let isSuccess: Bool
    }

    struct CovHSendFee {
        let value: BigUInt?
    }

    var accountInfos: [CovHSendInfo] = []
    var minimumBalances: [BigUInt] = []
    var fees: [CovHSendFee] = []
    var tips: [Bool] = []
    var scamDeliveries = 0
    var possibleChains: [[ChainModel]?] = []
    var eqBalances: [Decimal] = []
    var dependencies: [ChainAsset] = []
    var dependencyErrors: [Error] = []
    var assetAccountInfos = 0
    var assetAccountInfoErrors = 0

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) {
        if case .success = result {
            accountInfos.append(CovHSendInfo(asset: chainAsset, isSuccess: true))
        } else {
            accountInfos.append(CovHSendInfo(asset: chainAsset, isSuccess: false))
        }
    }

    func didReceiveMinimumBalance(result: Result<BigUInt, Error>) {
        if case let .success(value) = result { minimumBalances.append(value) }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) {
        fees.append(CovHSendFee(value: (try? result.get())?.inclusionFee.baseFee))
    }

    func didReceiveTip(result: Result<BigUInt, Error>) {
        if case .success = result { tips.append(true) } else { tips.append(false) }
    }

    func didReceive(scamInfo _: ScamInfo?) { scamDeliveries += 1 }
    func didReceive(possibleChains: [ChainModel]?) { self.possibleChains.append(possibleChains) }
    func didReceive(eqTotalBalance: Decimal) { eqBalances.append(eqTotalBalance) }
    func didReceiveDependencies(for chainAsset: ChainAsset) { dependencies.append(chainAsset) }
    func didReceiveDependenciesError(_ error: Error, for _: ChainAsset) { dependencyErrors.append(error) }
    func didReceiveAssetAccountInfo(assetAccountInfo _: AssetAccountInfo?) { assetAccountInfos += 1 }
    func didReceiveAssetAccountInfoError(error _: Error) { assetAccountInfoErrors += 1 }
}

final class CovHSendExistentialDeposit: ExistentialDepositServiceProtocol {
    var requested: [ChainAsset] = []
    var result: Result<BigUInt, Error> = .success(5)

    func fetchExistentialDeposit(chainAsset: ChainAsset, completion: @escaping (Result<BigUInt, Error>) -> Void) {
        requested.append(chainAsset)
        completion(result)
    }
}

final class CovHSendAccountInfoFetching: AccountInfoFetchingProtocol {
    var requested: [ChainAsset] = []

    func fetch(for chainAsset: ChainAsset, accountId _: AccountId, completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void) {
        requested.append(chainAsset)
        completionBlock(chainAsset, nil)
    }

    func fetch(for _: [ChainAsset], wallet _: MetaAccountModel, completionBlock: @escaping ([ChainAsset: AccountInfo?]) -> Void) {
        completionBlock([:])
    }

    func fetch(for chainAsset: ChainAsset, accountId _: AccountId) async throws -> (ChainAsset, AccountInfo?) { (chainAsset, nil) }
    func fetch(for _: [ChainAsset], wallet _: MetaAccountModel) async throws -> [ChainAsset: AccountInfo?] { [:] }
    func fetchByUniqKey(for _: [ChainAsset], wallet _: MetaAccountModel) async throws -> [ChainAssetKey: AccountInfo?] { [:] }
}

final class CovHSendScamFetching: ScamInfoFetching {
    private let lock = NSLock()
    private var stored: [String] = []

    var addresses: [String] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func fetch(address: String, chain _: ChainModel) async throws -> ScamInfo? {
        lock.lock()
        stored.append(address)
        lock.unlock()
        return nil
    }
}

final class CovHSendChainAssetFetching: ChainAssetFetchingProtocol {
    var result: Result<[ChainAsset], Error> = .success([])
    var filters: [[ChainAssetsFetching.Filter]] = []

    func fetch(
        shouldUseCache _: Bool,
        filters: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor],
        completionBlock: @escaping (Result<[ChainAsset], Error>?) -> Void
    ) {
        self.filters.append(filters)
        completionBlock(result)
    }

    func fetchAwaitOperation(
        shouldUseCache _: Bool,
        filters _: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor]
    ) -> BaseOperation<[ChainAsset]> {
        ClosureOperation { [] }
    }

    func fetchAwait(
        shouldUseCache _: Bool,
        filters _: [ChainAssetsFetching.Filter],
        sortDescriptors _: [ChainAssetsFetching.SortDescriptor]
    ) async throws -> [ChainAsset] {
        try result.get()
    }
}

final class CovHSendRuntimeService: RuntimeCodingServiceProtocol {
    var snapshot: RuntimeSnapshot?

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        let operation = BaseOperation<RuntimeCoderFactoryProtocol>()
        operation.result = .failure(CovHSendError.failed)
        return operation
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        throw CovHSendError.failed
    }
}

final class CovHSendEquilibriumService: EquilibriumTotalBalanceServiceProtocol {
    var accountInfos: [ChainAssetKey: AccountInfo?] = [:]
    var oraclePricesMap: [UInt64: BigUInt] = [:]

    func fetchTotalBalance(completion: @escaping ((BigUInt) -> Void)) { completion(.zero) }
    func totalBalanceAfterTransfer(chainAsset _: ChainAsset, amount _: Decimal) -> Decimal? { 7 }
}
