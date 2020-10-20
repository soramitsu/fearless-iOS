import Foundation

final class AccountInfoSubscription: StorageChildSubscribing {
    let address: String
    let storageKey: Data
    let logger: LoggerProtocol
    let eventCenter: EventCenterProtocol

    init(address: String,
         storageKey: Data,
         logger: LoggerProtocol,
         eventCenter: EventCenterProtocol) {
        self.address = address
        self.storageKey = storageKey
        self.logger = logger
        self.eventCenter = eventCenter
    }

    func processUpdate(_ data: Data?, blockHash: Data?) {
        logger.debug("Did account info update")
    }
}
