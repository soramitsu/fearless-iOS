extension Array {
    func uniq<T: Equatable>(predicate: (Self.Iterator.Element) -> T) -> [Self.Iterator.Element] {
        var unique: [Self.Iterator.Element] = self
        for (index, element) in unique.enumerated().reversed() {
            if unique.filter({ predicate($0) == predicate(element) }).count > 1 {
                unique.remove(at: index)
            }
        }
        return unique
    }
}
