import RobinHood
import IrohaCrypto

final class StakingBalanceInteractor {
    weak var presenter: StakingBalanceInteractorOutputProtocol!

    // Sungvalue provider factory с помо - для всех остальрых
    // - staking ledger, епередаю айдрес конторлелра из стешайтема

    // stakingmainInteractor subscripions
    // substratePRoviderFactory создаею подписку на стэайтем
    ///
    private let chain: Chain
    private let accountAddress: AccountAddress
    private let runtimeCodingService: RuntimeCodingServiceProtocol
    private let chainStorage: AnyDataProviderRepository<ChainStorageItem>
    private let localStorageRequestFactory: LocalStorageRequestFactoryProtocol
    private let operationManager: OperationManagerProtocol
    private let priceProvider: AnySingleValueProvider<PriceData>
    private let providerFactory: SingleValueProviderFactoryProtocol
    private var electionStatusProvider: AnyDataProvider<DecodedElectionStatus>?

    init(
        chain: Chain,
        accountAddress: AccountAddress,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        chainStorage: AnyDataProviderRepository<ChainStorageItem>,
        localStorageRequestFactory: LocalStorageRequestFactoryProtocol,
        priceProvider: AnySingleValueProvider<PriceData>,
        providerFactory: SingleValueProviderFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.chain = chain
        self.accountAddress = accountAddress
        self.runtimeCodingService = runtimeCodingService
        self.chainStorage = chainStorage
        self.localStorageRequestFactory = localStorageRequestFactory
        self.priceProvider = priceProvider
        self.providerFactory = providerFactory
        self.operationManager = operationManager
    }

    func createStakingBalance() -> CompoundOperationWrapper<StakingBalanceData?> {
        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()

        let stakingLedgerWrapper = createStakingLedgerOperation(
            for: accountAddress,
            dependingOn: codingFactoryOperation
        )

        let activeEraWrapper: CompoundOperationWrapper<ActiveEraInfo?> =
            localStorageRequestFactory.queryItems(
                repository: chainStorage,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                params: StorageRequestParams(path: .activeEra)
            )

        let mappingOperation = createBalanceMappingOperation(
            stakingLedgerWrapper: stakingLedgerWrapper,
            activeEraWrapper: activeEraWrapper
        )

        let storageOperations =
            activeEraWrapper.allOperations + stakingLedgerWrapper.allOperations

        storageOperations.forEach { storageOperation in
            storageOperation.addDependency(codingFactoryOperation)
            mappingOperation.addDependency(storageOperation)
        }

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [codingFactoryOperation] + storageOperations
        )
    }

    private func createStakingLedgerOperation(
        for accountAddress: AccountAddress,
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<DyStakingLedger?> {
        let controllerWrapper: CompoundOperationWrapper<Data?> =
            localStorageRequestFactory
                .queryItems(
                    repository: chainStorage,
                    keyParam: { try SS58AddressFactory().accountId(from: accountAddress) },
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    params: StorageRequestParams(path: .controller)
                )

        let controllerKey: () throws -> Data = {
            if let controllerAccountId = try controllerWrapper.targetOperation.extractNoCancellableResultData() {
                return controllerAccountId
            } else {
                throw BaseOperationError.unexpectedDependentResult
            }
        }

        let controllerLedgerWrapper: CompoundOperationWrapper<DyStakingLedger?> =
            localStorageRequestFactory.queryItems(
                repository: chainStorage,
                keyParam: controllerKey,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                params: StorageRequestParams(path: .stakingLedger)
            )

        controllerLedgerWrapper.allOperations.forEach { $0.addDependency(controllerWrapper.targetOperation) }

        let dependencies = controllerWrapper.allOperations + controllerLedgerWrapper.dependencies

        return CompoundOperationWrapper(
            targetOperation: controllerLedgerWrapper.targetOperation,
            dependencies: dependencies
        )
    }

    private func createBalanceMappingOperation(
        stakingLedgerWrapper: CompoundOperationWrapper<DyStakingLedger?>,
        activeEraWrapper: CompoundOperationWrapper<ActiveEraInfo?>
    ) -> BaseOperation<StakingBalanceData?> {
        ClosureOperation<StakingBalanceData?> {
            guard
                let activeEra = try activeEraWrapper
                .targetOperation.extractNoCancellableResultData()?.index,
                let stakingLedger = try stakingLedgerWrapper
                .targetOperation.extractNoCancellableResultData()
            else { return nil }

            let balanceData = self.createStakingBalance(
                stakingLedger,
                activeEra: activeEra
            )
            return balanceData
        }
    }

    func createStakingBalance(
        _ stakingInfo: DyStakingLedger,
        activeEra: UInt32
    ) -> StakingBalanceData {
        StakingBalanceData(
            bonded: stakingInfo.active,
            unbonding: stakingInfo.unbounding(inEra: activeEra),
            redeemable: stakingInfo.redeemable(inEra: activeEra)
        )
    }

    private func subscribeToPriceChanges() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            if changes.isEmpty {
                self?.presenter.didReceive(priceResult: .success(nil))
            } else {
                for change in changes {
                    switch change {
                    case let .insert(item), let .update(item):
                        self?.presenter.didReceive(priceResult: .success(item))
                    case .delete:
                        self?.presenter.didReceive(priceResult: .success(nil))
                    }
                }
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(priceResult: .failure(error))
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )
        priceProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    func subscribeToElectionStatus() {
        guard electionStatusProvider == nil else {
            return
        }

        guard let electionStatusProvider = try? providerFactory
            .getElectionStatusProvider(chain: chain, runtimeService: runtimeCodingService)
        else {
            return
        }

        self.electionStatusProvider = electionStatusProvider

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedElectionStatus>]) in
            if let electionStatus = changes.reduceToLastChange() {
                self?.presenter.didReceive(electionStatusResult: .success(electionStatus.item))
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(electionStatusResult: .failure(error))
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )
        electionStatusProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func subsribeToActiveEra() {
        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()

        let activeEraWrapper: CompoundOperationWrapper<ActiveEraInfo?> =
            localStorageRequestFactory.queryItems(
                repository: chainStorage,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                params: StorageRequestParams(path: .activeEra)
            )
        activeEraWrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let activeEra = try activeEraWrapper
                        .targetOperation.extractNoCancellableResultData()?.index
                    self.presenter.didReceive(activeEraResult: .success(activeEra))
                } catch {
                    self.presenter.didReceive(activeEraResult: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: activeEraWrapper.allOperations + [codingFactoryOperation], in: .transient)
    }
}

extension StakingBalanceInteractor: StakingBalanceInteractorInputProtocol {
    func setup() {
        subscribeToPriceChanges()
        subscribeToElectionStatus()
        subsribeToActiveEra()
    }
}
