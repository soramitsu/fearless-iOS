import Foundation

protocol ListReducing {
    associatedtype InputType
    associatedtype OutputType

    func reduce(list: [InputType], initialValue: OutputType) -> OutputType
}

class AnyReducer<T, R>: ListReducing {
    typealias InputType = T
    typealias OutputType = R

    private let privateReduce: ([T], R) -> R

    init<U: ListReducing>(reducer: U) where U.InputType == InputType, U.OutputType == OutputType {
        privateReduce = reducer.reduce
    }

    func reduce(list: [T], initialValue: R) -> R {
        privateReduce(list, initialValue)
    }
}
