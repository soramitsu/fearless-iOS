public extension Sequence {
    func asyncMap<T>(
        _ closure: @Sendable (Element) async throws -> T
    ) async rethrows -> [T] {
        var array: [T] = []
        array.reserveCapacity(underestimatedCount)
        for element in self {
            try array.append(await closure(element))
        }
        return array
    }

    func asyncCompactMap<T>(
        _ transform: (Element) async throws -> T?
    ) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            guard let value = try await transform(element) else {
                continue
            }

            values.append(value)
        }

        return values
    }

    func concurrentMap<T>(
        _ transform: @escaping (Element) async throws -> T?
    ) async throws -> [T] {
        let tasks = compactMap { element in
            Task {
                try await transform(element)
            }
        }

        return try await tasks.asyncCompactMap { task in
            try await task.value
        }
    }
}
