import Foundation

extension Sequence where Element: Hashable {
    func withoutDuplicates() -> [Element] {
        var set = Set<Element>()
        return filter { set.insert($0).inserted }
    }
}
