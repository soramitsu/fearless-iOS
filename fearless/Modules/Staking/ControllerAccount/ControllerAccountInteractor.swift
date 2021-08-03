import UIKit
import SoraKeystore
import RobinHood
import IrohaCrypto
import FearlessUtils

final class ControllerAccountInteractor {
    weak var presenter: ControllerAccountInteractorOutputProtocol!

    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    private let selectedAccountAddress: AccountAddress
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let operationManager: OperationManagerProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let engine: JSONRPCEngine
    private let chain: Chain
    private lazy var callFactory = SubstrateCallFactory()
    private lazy var addressFactory = SS58AddressFactory()

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var extrinsicService: ExtrinsicServiceProtocol?

    init(
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        selectedAccountAddress: AccountAddress,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        operationManager: OperationManagerProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        engine: JSONRPCEngine,
        chain: Chain
    ) {
        self.singleValueProviderFactory = singleValueProviderFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.runtimeService = runtimeService
        self.selectedAccountAddress = selectedAccountAddress
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.feeProxy = feeProxy
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.storageRequestFactory = storageRequestFactory
        self.engine = engine
        self.chain = chain
    }
}

extension ControllerAccountInteractor: ControllerAccountInteractorInputProtocol {
    func setup() {
        stashItemProvider = subscribeToStashItemProvider(for: selectedAccountAddress)

        fetchAllAccounts(
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            self?.presenter.didReceiveAccounts(result: result)
        }
        feeProxy.delegate = self
    }

    func estimateFee(for account: AccountItem) {
        guard let extrinsicService = extrinsicService else { return }
        do {
            let setController = try callFactory.setController(account.address)
            let identifier = setController.callName + account.identifier

            feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: identifier) { builder in
                try builder.adding(call: setController)
            }
        } catch {
            presenter.didReceiveFee(result: .failure(error))
        }
    }

    func fetchControllerAccountInfo(controllerAddress: AccountAddress) {
        do {
            let accountId = try addressFactory.accountId(fromAddress: controllerAddress, type: chain.addressType)

            let accountInfoOperation = createAccountInfoFetchOperation(accountId)
            accountInfoOperation.targetOperation.completionBlock = { [weak presenter] in
                DispatchQueue.main.async {
                    do {
                        let accountInfo = try accountInfoOperation.targetOperation.extractNoCancellableResultData()
                        presenter?.didReceiveAccountInfo(result: .success(accountInfo), address: controllerAddress)
                    } catch {
                        presenter?.didReceiveAccountInfo(result: .failure(error), address: controllerAddress)
                    }
                }
            }
            operationManager.enqueue(operations: accountInfoOperation.allOperations, in: .transient)
        } catch {
            presenter.didReceiveAccountInfo(result: .failure(error), address: controllerAddress)
        }
    }

    func fetchLedger(controllerAddress: AccountAddress) {
        do {
            let accountId = try addressFactory.accountId(fromAddress: controllerAddress, type: chain.addressType)

            let ledgerOperataion = createLedgerFetchOperation(accountId)
            ledgerOperataion.targetOperation.completionBlock = { [weak presenter] in
                DispatchQueue.main.async {
                    do {
                        let ledger = try ledgerOperataion.targetOperation.extractNoCancellableResultData()
                        presenter?.didReceiveStakingLedger(result: .success(ledger))
                    } catch {
                        presenter?.didReceiveStakingLedger(result: .failure(error))
                    }
                }
            }
            operationManager.enqueue(
                operations: ledgerOperataion.allOperations,
                in: .transient
            )
        } catch {
            presenter.didReceiveStakingLedger(result: .failure(error))
        }
    }

    private func createLedgerFetchOperation(_ accountId: AccountId) -> CompoundOperationWrapper<StakingLedger?> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<StakingLedger>]> = storageRequestFactory.queryItems(
            engine: engine,
            keyParams: { [accountId] },
            factory: { try coderFactoryOperation.extractNoCancellableResultData() },
            storagePath: .stakingLedger
        )

        let mapOperation = ClosureOperation<StakingLedger?> {
            try wrapper.targetOperation.extractNoCancellableResultData().first?.value
        }

        wrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        let dependencies = [coderFactoryOperation] + wrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    private func createAccountInfoFetchOperation(
        _ accountId: Data
    ) -> CompoundOperationWrapper<AccountInfo?> {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let wrapper: CompoundOperationWrapper<[StorageResponse<AccountInfo>]> = storageRequestFactory.queryItems(
            engine: engine,
            keyParams: { [accountId] },
            factory: { try coderFactoryOperation.extractNoCancellableResultData() },
            storagePath: .account
        )

        let mapOperation = ClosureOperation<AccountInfo?> {
            try wrapper.targetOperation.extractNoCancellableResultData().first?.value
        }

        wrapper.allOperations.forEach { $0.addDependency(coderFactoryOperation) }

        let dependencies = [coderFactoryOperation] + wrapper.allOperations

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}

extension ControllerAccountInteractor: SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler,
    SingleValueProviderSubscriber, SingleValueSubscriptionHandler, AnyProviderAutoCleaning, AccountFetching {
    func handleStashItem(result: Result<StashItem?, Error>) {
        do {
            clear(dataProvider: &accountInfoProvider)

            let maybeStashItem = try result.get()
            presenter.didReceiveStashItem(result: .success(maybeStashItem))

            if let stashItem = maybeStashItem {
                handle(stashItem: stashItem)
            }
        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
        }
    }

    func handleAccountInfo(result: Result<AccountInfo?, Error>, address: AccountAddress) {
        presenter.didReceiveAccountInfo(result: result, address: address)
    }

    func handleLedgerInfo(result: Result<StakingLedger?, Error>, address _: AccountAddress) {
        presenter.didReceiveStakingLedger(result: result)
    }

    private func handle(stashItem: StashItem) {
        accountInfoProvider = subscribeToAccountInfoProvider(
            for: stashItem.stash,
            runtimeService: runtimeService
        )
        fetchAccount(
            for: stashItem.stash,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            switch result {
            case let .success(accountItem):
                if let accountItem = accountItem {
                    self?.extrinsicService = self?.extrinsicServiceFactory.createService(accountItem: accountItem)
                    self?.estimateFee(for: accountItem)
                }
                self?.presenter.didReceiveStashAccount(result: .success(accountItem))
            case let .failure(error):
                self?.presenter.didReceiveStashAccount(result: .failure(error))
            }
        }

        fetchAccount(
            for: stashItem.controller,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            if case let .success(maybeController) = result, let controller = maybeController {
                self?.estimateFee(for: controller)
            }

            self?.presenter.didReceiveControllerAccount(result: result)
        }
    }
}

extension ControllerAccountInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
