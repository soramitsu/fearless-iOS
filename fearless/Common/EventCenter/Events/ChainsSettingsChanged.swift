import Foundation

struct ChainsSettingsChanged: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processChainsSettingsChanged()
    }
}
