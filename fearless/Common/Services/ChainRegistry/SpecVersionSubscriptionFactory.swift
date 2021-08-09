import Foundation

protocol SpecVersionSubscriptionFactoryProtocol: AnyObject {
    func createSubscription(for connection: JSONRPCEngine) -> SpecVersionSubscriptionProtocol
}

final class SpecVersionSubscriptionFactory {
    let runtimeSyncService: RuntimeSyncServiceProtocol

    init(runtimeSyncService: RuntimeSyncServiceProtocol) {
        self.runtimeSyncService = runtimeSyncService
    }
}

extension SpecVersionSubscriptionFactory: SpecVersionSubscriptionFactoryProtocol {
    func createSubscription(for connection: JSONRPCEngine) -> SpecVersionSubscriptionProtocol {
        SpecVersionSubscription(runtimeSyncService: runtimeSyncService, connection: connection)
    }
}
