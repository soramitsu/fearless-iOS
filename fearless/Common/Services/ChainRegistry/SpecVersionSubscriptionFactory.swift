import Foundation

protocol SpecVersionSubscriptionFactoryProtocol: AnyObject {
    func createSubscription(
        for chainId: ChainModel.Id,
        connection: JSONRPCEngine
    ) -> SpecVersionSubscriptionProtocol
}

final class SpecVersionSubscriptionFactory {
    let runtimeSyncService: RuntimeSyncServiceProtocol
    let logger: LoggerProtocol

    init(runtimeSyncService: RuntimeSyncServiceProtocol, logger: LoggerProtocol) {
        self.runtimeSyncService = runtimeSyncService
        self.logger = logger
    }
}

extension SpecVersionSubscriptionFactory: SpecVersionSubscriptionFactoryProtocol {
    func createSubscription(
        for chainId: ChainModel.Id,
        connection: JSONRPCEngine
    ) -> SpecVersionSubscriptionProtocol {
        SpecVersionSubscription(
            chainId: chainId,
            runtimeSyncService: runtimeSyncService,
            connection: connection
        )
    }
}
