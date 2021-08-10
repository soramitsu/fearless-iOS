import UIKit
import RobinHood
import IrohaCrypto

final class AnalyticsValidatorsInteractor {
    weak var presenter: AnalyticsValidatorsInteractorOutputProtocol!
    let identityOperationFactory: IdentityOperationFactoryProtocol
    let operationManager: OperationManagerProtocol
    let engine: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let chain: Chain

    private var identitiesByAddress: [AccountAddress: AccountIdentity]?

    init(
        identityOperationFactory: IdentityOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        chain: Chain
    ) {
        self.identityOperationFactory = identityOperationFactory
        self.operationManager = operationManager
        self.engine = engine
        self.runtimeService = runtimeService
        self.chain = chain
    }

    private func fetchValidatorIdentity(accountIds: [AccountId]) {
        let operation = identityOperationFactory.createIdentityWrapper(
            for: { accountIds },
            engine: engine,
            runtimeService: runtimeService,
            chain: chain
        )
        operation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let identitiesByAddress = try operation.targetOperation.extractNoCancellableResultData()
                    self?.presenter.didReceive(identitiesByAddressResult: .success(identitiesByAddress))
                } catch {
                    self?.presenter.didReceive(identitiesByAddressResult: .failure(error))
                }
            }
        }
        operationManager.enqueue(operations: operation.allOperations, in: .transient)
    }
}

extension AnalyticsValidatorsInteractor: AnalyticsValidatorsInteractorInputProtocol {
    func setup() {
        let addresses = [
            "5FZoQhgUCmqBxnkHX7jCqThScS2xQWiwiF61msg63CFL3Y8f",
            "5Ek5JCnrRsyUGYNRaEvkufG1i1EUxEE9cytuWBBjA9oNZVsf"
        ]
        let addressFactory = SS58AddressFactory()
        let accountIds = addresses.compactMap { try? addressFactory.accountId(from: $0) }
        fetchValidatorIdentity(accountIds: accountIds)
    }
}
