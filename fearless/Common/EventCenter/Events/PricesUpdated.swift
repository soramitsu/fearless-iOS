import Foundation

struct PricesUpdated: EventProtocol {
    func accept(visitor: any EventVisitorProtocol) {
        visitor.processPricesUpdated()
    }
}
