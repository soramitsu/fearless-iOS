import Foundation

extension Collection where Iterator.Element: Hashable {
    func toSet() -> Set<Iterator.Element> {
        Set(self)
    }
}

extension Set {
    func toArray() -> [Element] {
        Array(self)
    }
}
