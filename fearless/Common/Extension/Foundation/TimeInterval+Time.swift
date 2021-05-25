import Foundation

extension TimeInterval {
    var milliseconds: Int { Int(1000 * self) }
    var seconds: TimeInterval { self / 1000 }
}
