import RobinHood

protocol ExtrinsicServiceFactoryProtocol {
    func createService(accountItem: AccountItem) -> ExtrinsicServiceProtocol
}

final class ExtrinsicServiceFactory {
    private let runtimeRegistry: RuntimeCodingServiceProtocol
    private let engine: JSONRPCEngine
    private let operationManager: OperationManagerProtocol

    init(
        runtimeRegistry: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol
    ) {
        self.runtimeRegistry = runtimeRegistry
        self.engine = engine
        self.operationManager = operationManager
    }
}

extension ExtrinsicServiceFactory: ExtrinsicServiceFactoryProtocol {
    func createService(accountItem: AccountItem) -> ExtrinsicServiceProtocol {
        ExtrinsicService(
            address: accountItem.address,
            cryptoType: accountItem.cryptoType,
            runtimeRegistry: runtimeRegistry,
            engine: engine,
            operationManager: operationManager
        )
    }
}
