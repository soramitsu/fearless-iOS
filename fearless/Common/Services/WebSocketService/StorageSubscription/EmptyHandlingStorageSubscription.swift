import Foundation
import RobinHood

final class EmptyHandlingStorageSubscription: BaseStorageChildSubscription {
    override func handle(result: Result<DataProviderChange<ChainStorageItem>?, Error>, blockHash: Data?) {
        logger.debug("Did handle update for key: \(remoteStorageKey.toHex(includePrefix: true))")
    }
}
