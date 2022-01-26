import UIKit
import RobinHood
import BigInt
import FearlessUtils

final class ChainAccountInteractor {
    weak var presenter: ChainAccountInteractorOutputProtocol?
    private let selectedMetaAccount: MetaAccountModel
    private let chain: ChainModel
    private let asset: AssetModel
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let storageRequestFactory: StorageRequestFactoryProtocol
    let connection: JSONRPCEngine

    init(
        selectedMetaAccount: MetaAccountModel,
        chain: ChainModel,
        asset: AssetModel,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine,
        operationManager: OperationManagerProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) {
        self.selectedMetaAccount = selectedMetaAccount
        self.chain = chain
        self.asset = asset
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.connection = connection
        self.storageRequestFactory = storageRequestFactory
        self.runtimeService = runtimeService
        self.operationManager = operationManager
    }

    private func subscribeToAccountInfo() {
        if let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId {
            _ = subscribeToAccountInfoProvider(for: accountId, chainId: chain.chainId)
        } else {
            presenter?.didReceiveAccountInfo(
                result: .failure(ChainAccountFetchingError.accountNotExists),
                for: chain.chainId
            )
        }
    }

    private func fetchBalanceLocks() {
        if let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId {
            let balanceLocksOperation = createBalanceLocksFetchOperation(accountId)
            balanceLocksOperation.targetOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    do {
                        let balanceLocks = try balanceLocksOperation.targetOperation.extractNoCancellableResultData()
                        self?.presenter?.didReceiveBalanceLocks(result: .success(balanceLocks))
                    } catch {
                        self?.presenter?.didReceiveBalanceLocks(result: .failure(error))
                    }
                }
            }
            operationManager.enqueue(
                operations: balanceLocksOperation.allOperations,
                in: .transient
            )
        }
    }

    private func createBalanceLocksFetchOperation(_ accountId: AccountId) -> CompoundOperationWrapper<BalanceLocks?> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<BalanceLocks>]> = storageRequestFactory.queryItems(
            engine: connection,
            keyParams: { [accountId] },
            factory: { try coderFactoryOperation.extractNoCancellableResultData() },
            storagePath: .balanceLocks
        )

        let mapOperation = ClosureOperation<BalanceLocks?> {
            try wrapper.targetOperation.extractNoCancellableResultData().first?.value
        }

        wrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        let dependencies = [coderFactoryOperation] + wrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}

extension ChainAccountInteractor: ChainAccountInteractorInputProtocol {
    func setup() {
        subscribeToAccountInfo()
        fetchMinimalBalance()
        fetchBalanceLocks()

        if let priceId = asset.priceId {
            _ = subscribeToPrice(for: priceId)
        }
    }
}

extension ChainAccountInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        presenter?.didReceivePriceData(result: result, for: priceId)
    }
}

extension ChainAccountInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId: ChainModel.Id
    ) {
        presenter?.didReceiveAccountInfo(result: result, for: chainId)
    }
}

extension ChainAccountInteractor: RuntimeConstantFetching {
    func fetchMinimalBalance() {
        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<BigUInt, Error>) in
            self?.presenter?.didReceiveMinimumBalance(result: result)
        }
    }
}
