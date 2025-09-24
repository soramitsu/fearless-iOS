import Foundation

struct AccountScoreSettingsChanged: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processAccountScoreSettingsChanged()
    }
}
