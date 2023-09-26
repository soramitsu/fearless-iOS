import Foundation

struct ChainsSetupCompleted: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processChainsSetupCompleted()
    }
}
