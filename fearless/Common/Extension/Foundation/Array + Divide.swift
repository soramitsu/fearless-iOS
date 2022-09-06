extension Array {
    func divide(
        predicate: (Self.Iterator.Element) -> Bool
    ) -> (slice: [Self.Iterator.Element], remainder: [Self.Iterator.Element]) {
        var slice: [Self.Iterator.Element] = []
        var remainder: [Self.Iterator.Element] = []
        forEach {
            switch predicate($0) {
            case true: slice.append($0)
            case false: remainder.append($0)
            }
        }
        return (slice, remainder)
    }
}
