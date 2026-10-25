import Foundation

public extension Data {
    var miniSeed: Data {
        count > 32 ? Data(self[0 ..< 32]) : self
    }
}
