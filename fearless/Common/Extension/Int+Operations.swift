import Foundation

extension Int {
    func firstDivider(from range: ClosedRange<Int>) -> Int? {
        range.first { self % $0 == 0 }
    }
}
