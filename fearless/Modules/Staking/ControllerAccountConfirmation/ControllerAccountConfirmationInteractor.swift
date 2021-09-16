import UIKit
import RobinHood
import IrohaCrypto
import FearlessUtils

final class ControllerAccountConfirmationInteractor {
    weak var presenter: ControllerAccountConfirmationInteractorOutputProtocol!

    let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    private let selectedAccountAddress: AccountAddress
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    private let signingWrapper: SigningWrapperProtocol
    private let assetId: WalletAssetId
    private let controllerAccountItem: AccountItem
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let operationManager: OperationManagerProtocol
    private let storageRequestFactory: StorageRequestFactoryProtocol
    private let engine: JSONRPCEngine
    private let chain: Chain
    private lazy var callFactory = SubstrateCallFactory()
    private lazy var addressFactory = SS58AddressFactory()

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var extrinsicService: ExtrinsicServiceProtocol?

    init(
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        assetId: WalletAssetId,
        controllerAccountItem: AccountItem,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        operationManager: OperationManagerProtocol,
        storageRequestFactory: StorageRequestFactoryProtocol,
        selectedAccountAddress: AccountAddress,
        engine: JSONRPCEngine,
        chain: Chain
    ) {
        self.singleValueProviderFactory = singleValueProviderFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.runtimeService = runtimeService
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.signingWrapper = signingWrapper
        self.feeProxy = feeProxy
        self.assetId = assetId
        self.controllerAccountItem = controllerAccountItem
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.storageRequestFactory = storageRequestFactory
        self.selectedAccountAddress = selectedAccountAddress
        self.engine = engine
        self.chain = chain
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
        stashItemProvider = subscribeToStashItemProvider(for: selectedAccountAddress)
        priceProvider = subscribeToPriceProvider(for: assetId)
        estimateFee()
        feeProxy.delegate = self
    }

    func confirm() {
        do {
            let setController = try callFactory.setController(controllerAccountItem.address)

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
        fetchAccount(
            for: address,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            self?.presenter.didReceiveStashAccount(result: result)
        }
    }

    func estimateFee() {
        guard let extrinsicService = extrinsicService else { return }
        do {
            let setController = try callFactory.setController(controllerAccountItem.address)
            let identifier = setController.callName + controllerAccountItem.identifier

            feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: identifier) { builder in
                try builder.adding(call: setController)
            }
        } catch {
            presenter.didReceiveFee(result: .failure(error))
        }
    }

    func fetchLedger() {
        do {
            let accountId = try addressFactory.accountId(
                fromAddress: controllerAccountItem.address,
                type: chain.addressType
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
}

extension ControllerAccountConfirmationInteractor: SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler,
    SingleValueProviderSubscriber, SingleValueSubscriptionHandler, AccountFetching, AnyProviderAutoCleaning {
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

    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter.didReceivePriceData(result: result)
    }

    func handleAccountInfo(result: Result<AccountInfo?, Error>, address _: AccountAddress) {
        presenter.didReceiveAccountInfo(result: result)
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
                    self?.estimateFee()
                }
                self?.presenter.didReceiveStashAccount(result: .success(accountItem))
            case let .failure(error):
                self?.presenter.didReceiveStashAccount(result: .failure(error))
            }
        }
    }
}

extension ControllerAccountConfirmationInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
