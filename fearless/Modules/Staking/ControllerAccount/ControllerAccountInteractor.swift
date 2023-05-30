import UIKit
import SoraKeystore
import RobinHood
import IrohaCrypto
import SSFUtils
import SSFModels

final class ControllerAccountInteractor {
    weak var presenter: ControllerAccountInteractorOutputProtocol!

    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    let stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let operationManager: OperationManagerProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let engine: JSONRPCEngine
    private let chainAsset: ChainAsset
    private let selectedAccount: MetaAccountModel
    private let callFactory: SubstrateCallFactoryProtocol
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var extrinsicService: ExtrinsicServiceProtocol?

    init(
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        engine: JSONRPCEngine,
        chainAsset: ChainAsset,
        selectedAccount: MetaAccountModel,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.runtimeService = runtimeService
        self.selectedAccount = selectedAccount
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
        self.storageRequestFactory = storageRequestFactory
        self.engine = engine
        self.chainAsset = chainAsset
        self.callFactory = callFactory
    }
}

extension ControllerAccountInteractor: ControllerAccountInteractorInputProtocol {
    func setup() {
        if let address = selectedAccount.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        fetchChainAccounts(
            chain: chainAsset.chain,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            self?.presenter.didReceiveAccounts(result: result)
        }

        feeProxy.delegate = self
    }

    func estimateFee(for account: ChainAccountResponse) {
        guard let extrinsicService = extrinsicService, let address = account.toAddress() else { return }
        do {
            let setController = try callFactory.setController(address, chainAsset: chainAsset)
            let identifier = setController.callName + account.name

            feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: identifier) { builder in
                try builder.adding(call: setController)
            }
        } catch {
            presenter.didReceiveFee(result: .failure(error))
        }
    }

    func fetchControllerAccountInfo(controllerAddress: AccountAddress) {
        do {
            let accountId = try AddressFactory.accountId(
                from: controllerAddress,
                chain: chainAsset.chain
            )

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
            let accountId = try AddressFactory.accountId(
                from: controllerAddress,
                chain: chainAsset.chain
            )

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

    private func handle(stashItem: StashItem) {
        if let accountId = try? AddressFactory.accountId(
            from: stashItem.stash,
            chain: chainAsset.chain
        ) {
            accountInfoSubscriptionAdapter.subscribe(
                chainAsset: chainAsset,
                accountId: accountId,
                handler: self
            )
        }

        fetchChainAccount(
            chain: chainAsset.chain,
            address: stashItem.stash,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            switch result {
            case let .success(accountItem):
                if let accountItem = accountItem {
                    self?.handleAccount(accountItem)
                }

                self?.presenter.didReceiveStashAccount(result: .success(accountItem))
            case let .failure(error):
                self?.presenter.didReceiveStashAccount(result: .failure(error))
            }
        }

        fetchChainAccount(
            chain: chainAsset.chain,
            address: stashItem.controller,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            if case let .success(account) = result, let account = account {
                self?.estimateFee(for: account)
            }

            self?.presenter.didReceiveControllerAccount(result: result)
        }
    }

    private func handleAccount(_ account: ChainAccountResponse) {
        extrinsicService = ExtrinsicService(
            accountId: account.accountId,
            chainFormat: chainAsset.chain.chainFormat,
            cryptoType: account.cryptoType,
            runtimeRegistry: runtimeService,
            engine: engine,
            operationManager: operationManager
        )

        estimateFee(for: account)
    }
}

extension ControllerAccountInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId: AccountId, chainAsset: ChainAsset) {
        guard let address = try? AddressFactory.address(
            for: accountId,
            chainFormat: chainAsset.chain.chainFormat
        ) else {
            return
        }

        presenter.didReceiveAccountInfo(result: result, address: address)
    }
}

extension ControllerAccountInteractor: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
    func handleLedgerInfo(result: Result<StakingLedger?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceiveStakingLedger(result: result)
    }

    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
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
}

extension ControllerAccountInteractor: AnyProviderAutoCleaning, AccountFetching {}

extension ControllerAccountInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
