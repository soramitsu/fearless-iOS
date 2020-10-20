import Foundation
import FearlessUtils
import IrohaCrypto

final class WebSocketSubscriptionFactory: WebSocketSubscriptionFactoryProtocol {
    func createSubscriptions(address: String,
                             type: SNAddressType,
                             engine: JSONRPCEngine) throws -> [WebSocketSubscribing] {
        let accountId = try SS58AddressFactory().accountId(fromAddress: address,
                                                           type: type)

        let keyFactory = StorageKeyFactory()

        let accountSubscription = try createAccountInfoSubscription(address,
                                                                    accountId: accountId,
                                                                    storageKeyFactory: keyFactory)

        let bondedSubscription = try createBondedSubscription(accountId: accountId,
                                                              storageKeyFactory: keyFactory)

        let children: [StorageChildSubscribing] = [accountSubscription, bondedSubscription]
        let container = StorageSubscriptionContainer(engine: engine,
                                                     children: children,
                                                     logger: Logger.shared)

        return [container]
    }

    private func createAccountInfoSubscription(_ address: String,
                                               accountId: Data,
                                               storageKeyFactory: StorageKeyFactoryProtocol)
        throws -> AccountInfoSubscription {
        let accountStorageKey = try storageKeyFactory.createStorageKey(moduleName: "System",
                                                                       serviceName: "Account",
                                                                       identifier: accountId)

        return AccountInfoSubscription(address: address,
                                       storageKey: accountStorageKey,
                                       logger: Logger.shared,
                                       eventCenter: EventCenter.shared)
    }

    private func createBondedSubscription(accountId: Data,
                                          storageKeyFactory: StorageKeyFactoryProtocol)
        throws -> BondedSubscription {
        let serviceKey = try storageKeyFactory.createStorageKey(moduleName: "Staking",
                                                                serviceName: "Bonded")

        let storageKey = serviceKey + accountId.twox64Concat()

        return BondedSubscription(storageKey: storageKey,
                                  logger: Logger.shared)
    }
}
