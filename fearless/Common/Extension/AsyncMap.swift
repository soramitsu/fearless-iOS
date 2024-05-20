import Foundation

extension Sequence {
    func asyncMap<T>(
        _ transform: (Element) async throws -> T?
    ) async rethrows -> [T] {
        var values = [T]()

        for element in self {
            if let transformed = try await transform(element) {
                values.append(transformed)
            }
        }

        return values
    }

    func asyncReduce<T>(
        _ initialResult: T,
        _ nextPartialResult:
        (_ partialResult: T, Element) async throws -> T
    ) async rethrows -> T {
        var accumulator = initialResult
        for element in self {
            accumulator = try await nextPartialResult(accumulator, element)
        }
        return accumulator
    }

    func asyncForEach(
        _ operation: (Element) async throws -> Void
    ) async rethrows {
        for element in self {
            try await operation(element)
        }
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
