import RobinHood
import IrohaCrypto
import BigInt

final class StakingBondMoreInteractor {
    weak var presenter: StakingBondMoreInteractorOutputProtocol!

    private let priceProvider: AnySingleValueProvider<PriceData>
    private let balanceProvider: AnyDataProvider<DecodedAccountInfo>
    private let stashItemProvider: StreamableProvider<StashItem>
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let extrinsicServiceFactoryProtocol: ExtrinsicServiceFactoryProtocol
    private var extrinsicService: ExtrinsicServiceProtocol?
    private let runtimeService: RuntimeCodingServiceProtocol
    private let operationManager: OperationManagerProtocol

    init(
        priceProvider: AnySingleValueProvider<PriceData>,
        balanceProvider: AnyDataProvider<DecodedAccountInfo>,
        stashItemProvider: StreamableProvider<StashItem>,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        extrinsicServiceFactoryProtocol: ExtrinsicServiceFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.priceProvider = priceProvider
        self.balanceProvider = balanceProvider
        self.stashItemProvider = stashItemProvider
        self.accountRepository = accountRepository
        self.extrinsicServiceFactoryProtocol = extrinsicServiceFactoryProtocol
        self.runtimeService = runtimeService
        self.operationManager = operationManager
    }

    private func subscribeToPriceChanges() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            let priceData = changes.reduceToLastChange()
            self?.presenter.didReceive(price: priceData)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(error: error)
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

    private func subscribeToAccountChanges() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedAccountInfo>]) in
            let balanceItem = changes.reduceToLastChange()?.item?.data
            self?.presenter.didReceive(balance: balanceItem)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(error: error)
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )
        balanceProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    func subscribeToStashItemProvider() {
        let changesClosure: ([DataProviderChange<StashItem>]) -> Void = { [weak self] changes in
            let stashItem = changes.reduceToLastChange()
            self?.handle(stashItem: stashItem)
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter.didReceive(stashItemResult: .failure(error))
            return
        }

        stashItemProvider.addObserver(
            self,
            deliverOn: .main,
            executing: changesClosure,
            failing: failureClosure,
            options: StreamableProviderObserverOptions.substrateSource()
        )
    }

    func handle(stashItem: StashItem?) {
        if let stashItem = stashItem {
            fetchStash(for: stashItem.stash)
        }

        presenter?.didReceive(stashItemResult: .success(stashItem))
    }

    func fetchStash(for address: AccountAddress) {
        let operation = accountRepository.fetchOperation(by: address, options: RepositoryFetchOptions())

        operation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let accountItem = try operation.extractNoCancellableResultData()
                    self.handleStashAccountItem(accountItem)
                } catch {
                    self.presenter.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func handleStashAccountItem(_ accountItem: AccountItem?) {
        guard let accountItem = accountItem else { return }
        extrinsicService = extrinsicServiceFactoryProtocol.createService(accountItem: accountItem)
        estimateFee(amount: 0)
    }
}

extension StakingBondMoreInteractor: StakingBondMoreInteractorInputProtocol {
    func setup() {
        subscribeToStashItemProvider()
        subscribeToPriceChanges()
        subscribeToAccountChanges()
    }

    private func createExtrinsicBuilderClosure(amount: BigUInt) -> ExtrinsicBuilderClosure {
        let callFactory = SubstrateCallFactory()

        let closure: ExtrinsicBuilderClosure = { builder in
            let call = try callFactory.bondExtra(amount: amount)
            _ = try builder.adding(call: call)
            return builder
        }

        return closure
    }

    func estimateFee(amount: BigUInt) {
        let closure = createExtrinsicBuilderClosure(amount: amount)
        extrinsicService?.estimateFee(closure, runningIn: .main) { [weak self] result in
            switch result {
            case let .success(info):
                self?.presenter.didReceive(paymentInfo: info, for: amount)
            case let .failure(error):
                self?.presenter.didReceive(error: error)
            }
        }
    }
}
