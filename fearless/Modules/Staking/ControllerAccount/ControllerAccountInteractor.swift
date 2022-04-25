import UIKit
import SoraKeystore
import RobinHood
import IrohaCrypto
import FearlessUtils

final class ControllerAccountInteractor {
    weak var presenter: ControllerAccountInteractorOutputProtocol!

    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let operationManager: OperationManagerProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let engine: JSONRPCEngine
    private let chain: ChainModel
    private let asset: AssetModel
    private let selectedAccount: MetaAccountModel
    private lazy var callFactory = SubstrateCallFactory()
    private lazy var addressFactory = SS58AddressFactory()

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var extrinsicService: ExtrinsicServiceProtocol?

    init(
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        engine: JSONRPCEngine,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.runtimeService = runtimeService
        self.selectedAccount = selectedAccount
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
        self.storageRequestFactory = storageRequestFactory
        self.engine = engine
        self.chain = chain
        self.asset = asset
    }
}

extension ControllerAccountInteractor: ControllerAccountInteractorInputProtocol {
    func setup() {
        if let address = selectedAccount.fetch(for: chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        fetchChainAccounts(
            chain: chain,
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
            let setController = try callFactory.setController(address)
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
            let accountId = try addressFactory.accountId(
                fromAddress: controllerAddress,
                addressPrefix: chain.addressPrefix
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
            let accountId = try addressFactory.accountId(
                fromAddress: controllerAddress,
                addressPrefix: chain.addressPrefix
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
        let addressFactory = SS58AddressFactory()

        if let accountId = try? addressFactory.accountId(fromAddress: stashItem.stash, type: chain.addressPrefix) {
            accountInfoProvider = subscribeToAccountInfoProvider(for: accountId, chainId: chain.chainId)
        }

        fetchChainAccount(chain: chain, address: stashItem.stash, from: accountRepository, operationManager: operationManager) { [weak self] result in
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

        fetchChainAccount(chain: chain, address: stashItem.controller, from: accountRepository, operationManager: operationManager) { [weak self] result in
            if case let .success(account) = result, let account = account {
                self?.estimateFee(for: account)
            }

            self?.presenter.didReceiveControllerAccount(result: result)
        }
    }

    private func handleAccount(_ account: ChainAccountResponse) {
        extrinsicService = ExtrinsicService(
            accountId: account.accountId,
            chainFormat: chain.chainFormat,
            cryptoType: account.cryptoType,
            runtimeRegistry: runtimeService,
            engine: engine,
            operationManager: operationManager
        )

        estimateFee(for: account)
    }
}

extension ControllerAccountInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId: AccountId, chainId _: ChainModel.Id) {
        let addressFactory = SS58AddressFactory()
        guard let address = try? addressFactory.address(
            fromAccountId: accountId,
            type: chain.addressPrefix
        ) else {
            return
        }

        presenter.didReceiveAccountInfo(result: result, address: address)
    }
}

extension ControllerAccountInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
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
