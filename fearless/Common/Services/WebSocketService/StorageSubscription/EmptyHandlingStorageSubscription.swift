import Foundation
import RobinHood

final class EmptyHandlingStorageSubscription<T: StorageWrapper>: BaseStorageChildSubscription<T> {
    override func handle(result _: Result<DataProviderChange<T>?, Error>, blockHash _: Data?) {
//        logger.debug("Did handle update for key: \(remoteStorageKey.toHex(includePrefix: true))")
    }
}
