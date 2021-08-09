import Foundation

// TODO: Will be implemented in FLW-1194

protocol SpecVersionSubscriptionProtocol: AnyObject {}

final class SpecVersionSubscription {
    let runtimeSyncService: RuntimeSyncServiceProtocol
    let connection: JSONRPCEngine

    init(runtimeSyncService: RuntimeSyncServiceProtocol, connection: JSONRPCEngine) {
        self.runtimeSyncService = runtimeSyncService
        self.connection = connection
    }
}

extension SpecVersionSubscription: SpecVersionSubscriptionProtocol {}
