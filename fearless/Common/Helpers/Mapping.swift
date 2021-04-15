import Foundation

protocol Mapping {
    associatedtype InputType
    associatedtype OutputType

    func map(input: InputType) -> OutputType
}

class AnyMapper<T, R>: Mapping {
    typealias InputType = T
    typealias OutputType = R

    private let privateMap: (T) -> R

    init<U: Mapping>(mapper: U) where U.InputType == InputType, U.OutputType == OutputType {
        privateMap = mapper.map
    }

    func map(input: InputType) -> OutputType {
        privateMap(input)
    }
}
