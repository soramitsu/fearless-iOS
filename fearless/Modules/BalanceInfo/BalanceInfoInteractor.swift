import UIKit
import RobinHood
import SSFUtils
import SSFModels

final class BalanceInfoInteractor {
    // MARK: - Private properties

    private weak var output: BalanceInfoInteractorOutput?

    private let balanceInfoType: BalanceInfoType
    private let walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol
    private let operationManager: OperationManagerProtocol
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let dependencyContainer = BalanceInfoDepencyContainer()

    init(
        balanceInfoType: BalanceInfoType,
        walletBalanceSubscriptionAdapter: WalletBalanceSubscriptionAdapterProtocol,
        operationManager: OperationManagerProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol
    ) {
        self.balanceInfoType = balanceInfoType
        self.walletBalanceSubscriptionAdapter = walletBalanceSubscriptionAdapter
        self.operationManager = operationManager
        self.storageRequestFactory = storageRequestFactory
    }
}

// MARK: - BalanceInfoInteractorInput

extension BalanceInfoInteractor: BalanceInfoInteractorInput {
    func setup(
        with output: BalanceInfoInteractorOutput,
        for type: BalanceInfoType
    ) {
        self.output = output
        fetchBalanceInfo(for: type)
    }

    func fetchBalanceInfo(for type: BalanceInfoType) {
        fetchBalance(for: type)
        if case let .chainAsset(wallet, chainAsset) = type {
            guard let dependencies = dependencyContainer.prepareDepencies(chainAsset: chainAsset) else {
                return
            }
            fetchMinimalBalance(for: chainAsset, service: dependencies.existentialDepositService)

            if let runtimeService = dependencies.runtimeService,
               let connection = dependencies.connection {
                fetchBalanceLocks(
                    for: wallet,
                    chainAsset: chainAsset,
                    runtimeService: runtimeService,
                    connection: connection
                )
            }
        }
    }
}

private extension BalanceInfoInteractor {
    func fetchBalance(for type: BalanceInfoType) {
        switch type {
        case let .wallet(metaAccount):
            walletBalanceSubscriptionAdapter.subscribeWalletBalance(
                wallet: metaAccount,
                deliverOn: .main,
                listener: self
            )
        case let .chainAsset(metaAccount, chainAsset):
            walletBalanceSubscriptionAdapter.subscribeChainAssetBalance(
                wallet: metaAccount,
                chainAsset: chainAsset,
                deliverOn: .main,
                listener: self
            )
        }
    }

    func fetchMinimalBalance(
        for chainAsset: ChainAsset,
        service: ExistentialDepositServiceProtocol
    ) {
        service.fetchExistentialDeposit(
            chainAsset: chainAsset
        ) { [weak self] result in
            self?.output?.didReceiveMinimumBalance(result: result)
        }
    }

    func fetchBalanceLocks(
        for wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine
    ) {
        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            let balanceLocksOperation = createBalanceLocksFetchOperation(
                for: accountId,
                runtimeService: runtimeService,
                connection: connection
            )
            balanceLocksOperation.targetOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    do {
                        let balanceLocks = try balanceLocksOperation.targetOperation.extractNoCancellableResultData()
                        self?.output?.didReceiveBalanceLocks(result: .success(balanceLocks))
                    } catch {
                        self?.output?.didReceiveBalanceLocks(result: .failure(error))
                    }
                }
            }
            operationManager.enqueue(
                operations: balanceLocksOperation.allOperations,
                in: .transient
            )
        }
    }

    func createBalanceLocksFetchOperation(
        for accountId: AccountId,
        runtimeService: RuntimeCodingServiceProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<BalanceLocks?> {
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

// MARK: - WalletBalanceSubscriptionHandler

extension BalanceInfoInteractor: WalletBalanceSubscriptionListener {
    var type: WalletBalanceListenerType {
        switch balanceInfoType {
        case let .wallet(wallet: wallet):
            return .wallet(wallet: wallet)
        case let .chainAsset(wallet: wallet, chainAsset: chainAsset):
            return .chainAsset(wallet: wallet, chainAsset: chainAsset)
        }
    }

    func handle(result: WalletBalancesResult) {
        output?.didReceiveWalletBalancesResult(result)
    }
}
