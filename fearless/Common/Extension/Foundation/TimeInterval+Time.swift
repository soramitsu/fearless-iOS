import Foundation

extension TimeInterval {
    static let secondsInDay: TimeInterval = 24 * 3600

    var milliseconds: Int { Int(1000 * self) }
    var seconds: TimeInterval { self / 1000 }
    var daysFromSeconds: Int { Int(self / Self.secondsInDay) }
}
