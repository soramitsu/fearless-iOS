import Foundation
import FearlessUtils

/**
 *  Protocol is designed to provide methods to create a subscription
 *  for runtime version in a particular chain
 */

protocol SpecVersionSubscriptionFactoryProtocol: AnyObject {
    /**
     *  Creates a subsription for runtime version in particular chain.
     *
     *  - Parameters:
     *      - chainId: Identifier of the chain for which subscription should be created;
     *      - connection: Connection to send request to the chain and receive updates.
     *
     *  - Returns: `SpecVersionSubscriptionProtocol` conforming subscription.
     */
    func createSubscription(
        for chainId: ChainModel.Id,
        connection: JSONRPCEngine
    ) -> SpecVersionSubscriptionProtocol
}

/**
 *  Class is designed to implement `SpecVersionSubscriptionFactoryProtocol` in a way to create
 *  `SpecVersionSubscription` subscription.
 */

final class SpecVersionSubscriptionFactory {
    let runtimeSyncService: RuntimeSyncServiceProtocol
    let logger: LoggerProtocol?

    /**
     *  Creates new subscription factory
     *
     *  - Paramaters:
     *      - runtimeSyncService: a sync service that is shared between
     *      subscriptions created by the factory;
     *      - logger: logger to provide info for debugging.
     */
    init(runtimeSyncService: RuntimeSyncServiceProtocol, logger: LoggerProtocol? = nil) {
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
