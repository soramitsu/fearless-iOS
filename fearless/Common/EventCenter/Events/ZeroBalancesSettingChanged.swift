import Foundation

struct ZeroBalancesSettingChanged: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processZeroBalancesSettingChanged()
    }
}
