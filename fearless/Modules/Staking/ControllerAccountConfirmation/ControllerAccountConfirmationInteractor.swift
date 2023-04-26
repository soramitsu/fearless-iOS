import UIKit
import RobinHood
import IrohaCrypto
import SSFUtils

final class ControllerAccountConfirmationInteractor {
    weak var presenter: ControllerAccountConfirmationInteractorOutputProtocol!

    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    let stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let signingWrapper: SigningWrapperProtocol
    private let controllerAccountItem: ChainAccountResponse
    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let operationManager: OperationManagerProtocol
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let engine: JSONRPCEngine
    private let chainAsset: ChainAsset
    private let selectedAccount: MetaAccountModel
    private let callFactory: SubstrateCallFactoryProtocol
    private lazy var addressFactory = SS58AddressFactory()

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var extrinsicService: ExtrinsicServiceProtocol?

    init(
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        signingWrapper: SigningWrapperProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        controllerAccountItem: ChainAccountResponse,
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        operationManager: OperationManagerProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        engine: JSONRPCEngine,
        chainAsset: ChainAsset,
        selectedAccount: MetaAccountModel,
        callFactory: SubstrateCallFactoryProtocol
    ) {
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.runtimeService = runtimeService
        self.extrinsicService = extrinsicService
        self.signingWrapper = signingWrapper
        self.feeProxy = feeProxy
        self.controllerAccountItem = controllerAccountItem
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.storageRequestFactory = storageRequestFactory
        self.selectedAccount = selectedAccount
        self.engine = engine
        self.chainAsset = chainAsset
        self.callFactory = callFactory
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
}

extension ControllerAccountConfirmationInteractor: ControllerAccountConfirmationInteractorInputProtocol {
    func setup() {
        if let address = selectedAccount.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        estimateFee()
        feeProxy.delegate = self
    }

    func confirm() {
        guard let address = controllerAccountItem.toAddress() else {
            return
        }
        do {
            let setController = try callFactory.setController(address)

            extrinsicService?.submit(
                { builder in
                    try builder.adding(call: setController)
                },
                signer: signingWrapper,
                runningIn: .main,
                completion: { [weak self] result in
                    self?.presenter.didConfirmed(result: result)
                }
            )
        } catch {
            presenter.didConfirmed(result: .failure(error))
        }
    }

    func fetchStashAccountItem(for address: AccountAddress) {
        fetchChainAccount(
            chain: chainAsset.chain,
            address: address,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            self?.presenter.didReceiveStashAccount(result: result)
        }
    }

    func estimateFee() {
        guard let extrinsicService = extrinsicService, let address = controllerAccountItem.toAddress() else { return }
        do {
            let setController = try callFactory.setController(address)
            let identifier = setController.callName + controllerAccountItem.name

            feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: identifier) { builder in
                try builder.adding(call: setController)
            }
        } catch {
            presenter.didReceiveFee(result: .failure(error))
        }
    }

    func fetchLedger() {
        guard let address = controllerAccountItem.toAddress() else {
            return
        }

        do {
            let accountId = try addressFactory.accountId(
                fromAddress: address,
                addressPrefix: chainAsset.chain.addressPrefix
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

    private func handle(stashItem: StashItem) {
        fetchChainAccount(
            chain: chainAsset.chain,
            address: stashItem.stash,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            guard let self = self else {
                return
            }

            switch result {
            case let .success(accountItem):
                if let accountItem = accountItem {
                    self.accountInfoSubscriptionAdapter.subscribe(
                        chainAsset: self.chainAsset,
                        accountId: accountItem.accountId,
                        handler: self
                    )

                    self.extrinsicService = ExtrinsicService(
                        accountId: accountItem.accountId,
                        chainFormat: self.chainAsset.chain.chainFormat,
                        cryptoType: accountItem.cryptoType,
                        runtimeRegistry: self.runtimeService,
                        engine: self.engine,
                        operationManager: self.operationManager
                    )

                    self.estimateFee()
                }
                self.presenter.didReceiveStashAccount(result: .success(accountItem))
            case let .failure(error):
                self.presenter.didReceiveStashAccount(result: .failure(error))
            }
        }
    }
}

extension ControllerAccountConfirmationInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension ControllerAccountConfirmationInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension ControllerAccountConfirmationInteractor: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
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

extension ControllerAccountConfirmationInteractor: AccountFetching, AnyProviderAutoCleaning {}

extension ControllerAccountConfirmationInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
