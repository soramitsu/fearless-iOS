import Foundation

final class BondedSubscription: StorageChildSubscribing {
    let storageKey: Data
    let logger: LoggerProtocol

    init(storageKey: Data,
         logger: LoggerProtocol) {
        self.storageKey = storageKey
        self.logger = logger
    }

    func processUpdate(_ data: Data?, blockHash: Data?) {
        if let controllerId = data {
            logger.debug("Did receive controller \(controllerId.toHex(includePrefix: true))")
        } else {
            logger.debug("No controller account found")
        }
    }
}
