import RobinHood
import SoraKeystore

protocol ExtrinsicServiceFactoryProtocol {
    func createService(accountItem: AccountItem) -> ExtrinsicServiceProtocol
    func createSigningWrapper(
        accountItem: AccountItem,
        connectionItem: ConnectionItem
    ) -> SigningWrapperProtocol
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

    func createSigningWrapper(
        accountItem: AccountItem,
        connectionItem: ConnectionItem
    ) -> SigningWrapperProtocol {
        var settings = InMemorySettingsManager()
        settings.selectedAccount = accountItem
        settings.selectedConnection = connectionItem

        return SigningWrapper(keystore: Keychain(), settings: settings)
    }
}
