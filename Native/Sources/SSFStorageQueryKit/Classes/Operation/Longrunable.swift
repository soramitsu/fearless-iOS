import Foundation

protocol Longrunable {
    associatedtype ResultType

    func start(with completionClosure: @escaping (Result<ResultType, Error>) -> Void)
    func cancel()
}

final class AnyLongrun<T>: Longrunable {
    typealias ResultType = T

    private let privateStart: (@escaping (Result<ResultType, Error>) -> Void) -> Void
    private let privateCancel: () -> Void

    init<U: Longrunable>(longrun: U) where U.ResultType == ResultType {
        privateStart = longrun.start
        privateCancel = longrun.cancel
    }

    func start(with completionClosure: @escaping (Result<T, Error>) -> Void) {
        privateStart(completionClosure)
    }

    func cancel() {
        privateCancel()
    }
}
