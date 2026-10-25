import Foundation

extension Data {
    var bytes: Data {
        return Data(self.map({ UInt8($0) }))
    }
}
