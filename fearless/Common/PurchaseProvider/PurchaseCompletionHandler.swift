import Foundation

final class PurchaseCompletionHandler {
    let callbackUrl: URL
    let eventCenter: EventCenterProtocol

    init(callbackUrl: URL, eventCenter: EventCenterProtocol) {
        self.callbackUrl = callbackUrl
        self.eventCenter = eventCenter
    }
}

extension PurchaseCompletionHandler: URLHandlingServiceProtocol {
    func handle(url: URL) -> Bool {
        if url == callbackUrl {
            eventCenter.notify(with: PurchaseCompleted())
            return true
        } else {
            return false
        }
    }
}
