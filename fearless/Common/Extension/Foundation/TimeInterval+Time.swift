import Foundation

extension TimeInterval {
    static let secondsInHour: TimeInterval = 3600
    static let secondsInDay: TimeInterval = 24 * secondsInHour

    var milliseconds: Int { Int(1000 * self) }
    var seconds: TimeInterval { self / 1000 }
    var daysFromSeconds: Int { Int(self / Self.secondsInDay) }
    var hoursFromSeconds: Int { Int(self / Self.secondsInHour) }
    var intervalsInDay: Int { self > 0.0 ? Int(Self.secondsInDay / self) : 0 }
}
