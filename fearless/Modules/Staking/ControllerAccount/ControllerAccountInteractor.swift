import UIKit
import SoraKeystore
import RobinHood

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
    private lazy var callFactory = SubstrateCallFactory()

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
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    ) {
        self.singleValueProviderFactory = singleValueProviderFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.runtimeService = runtimeService
        self.selectedAccountAddress = selectedAccountAddress
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.feeProxy = feeProxy
        self.extrinsicServiceFactory = extrinsicServiceFactory
    }

    private func handleStash(accountItem: AccountItem) {
        extrinsicService = extrinsicServiceFactory.createService(accountItem: accountItem)
        do {
            let setController = try callFactory.setController(accountItem.address)
            let identifier = setController.callName + accountItem.identifier

            feeProxy.estimateFee(using: extrinsicService!, reuseIdentifier: identifier) { builder in
                try builder.adding(call: setController)
            }
        } catch {
            presenter.didReceiveFee(result: .failure(error))
        }
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

    func estimateFee(for controllerAddress: AccountAddress) {
        do {
            let setController = try callFactory.setController(controllerAddress)
            let identifier = setController.callName + controllerAddress

            feeProxy.estimateFee(using: extrinsicService!, reuseIdentifier: identifier) { builder in
                try builder.adding(call: setController)
            }
        } catch {
            presenter.didReceiveFee(result: .failure(error))
        }
    }

    func fetchLedger(controllerAddress: AccountAddress) {
        clear(dataProvider: &ledgerProvider)
        ledgerProvider = subscribeToLedgerInfoProvider(
            for: controllerAddress,
            runtimeService: runtimeService
        )
    }
}

extension ControllerAccountInteractor: SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler,
    SingleValueProviderSubscriber, SingleValueSubscriptionHandler, AnyProviderAutoCleaning, AccountFetching {
    func handleStashItem(result: Result<StashItem?, Error>) {
        do {
            clear(dataProvider: &accountInfoProvider)

            let maybeStashItem = try result.get()
            if let stashItem = maybeStashItem {
                accountInfoProvider = subscribeToAccountInfoProvider(
                    for: stashItem.stash,
                    runtimeService: runtimeService
                )
                fetchAccount(
                    for: stashItem.stash,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    if case let .success(maybeStash) = result, let stash = maybeStash {
                        self?.handleStash(accountItem: stash)
                    }

                    self?.presenter.didReceiveStashAccount(result: result)
                }
            } else {
                presenter.didReceiveStashItem(result: .success(nil))
            }
        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
        }
    }

    func handleAccountInfo(result: Result<DyAccountInfo?, Error>, address _: AccountAddress) {
        presenter.didReceiveAccountInfo(result: result)
    }

    func handleLedgerInfo(result: Result<DyStakingLedger?, Error>, address _: AccountAddress) {
        presenter.didReceiveStakingLedger(result: result)
    }
}

extension ControllerAccountInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
