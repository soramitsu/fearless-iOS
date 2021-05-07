import UIKit
import SoraKeystore
import RobinHood

final class ControllerAccountInteractor {
    weak var presenter: ControllerAccountInteractorOutputProtocol!

    private let singleValueProviderFactory: SingleValueProviderFactoryProtocol
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    private let selectedAccountAddress: AccountAddress
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let operationManager: OperationManagerProtocol
    private let feeProxy: ExtrinsicFeeProxyProtocol
    private let extrinsicService: ExtrinsicServiceProtocol
    private lazy var callFactory = SubstrateCallFactory()

    private var stashItemProvider: StreamableProvider<StashItem>?

    init(
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        selectedAccountAddress: AccountAddress,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        operationManager: OperationManagerProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol
    ) {
        self.singleValueProviderFactory = singleValueProviderFactory
        self.substrateProviderFactory = substrateProviderFactory
        self.selectedAccountAddress = selectedAccountAddress
        self.accountRepository = accountRepository
        self.operationManager = operationManager
        self.feeProxy = feeProxy
        self.extrinsicService = extrinsicService
    }

    private func fetchAccounts() {
        let operation = accountRepository.fetchAllOperation(with: RepositoryFetchOptions())
        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let accounts = try operation.extractNoCancellableResultData()
                    self?.presenter.didReceiveAccounts(result: .success(accounts))
                } catch {
                    self?.presenter.didReceiveAccounts(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }
}

extension ControllerAccountInteractor: ControllerAccountInteractorInputProtocol {
    func setup() {
        stashItemProvider = subscribeToStashItemProvider(for: selectedAccountAddress)
        fetchAccounts()
        feeProxy.delegate = self
    }

    func estimateFee(controllerAddress: AccountAddress) {
        do {
            let setController = try callFactory.setController(controllerAddress)
            let identifier = setController.callName + controllerAddress

            feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: identifier) { builder in
                try builder.adding(call: setController)
            }
        } catch {
            presenter.didReceiveFee(result: .failure(error))
        }
    }
}

extension ControllerAccountInteractor: SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>) {
        presenter.didReceiveStashItem(result: result)
    }
}

extension ControllerAccountInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
