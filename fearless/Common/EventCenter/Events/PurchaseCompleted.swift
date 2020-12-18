import Foundation

struct PurchaseCompleted: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processPurchaseCompletion(event: self)
    }
}
