import Foundation

extension Int {
    func firstDivider(from range: [Int]) -> Int? {
        range.first { self % $0 == 0 }
    }
}
