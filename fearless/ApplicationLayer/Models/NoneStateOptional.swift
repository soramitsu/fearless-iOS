import Foundation

enum NoneStateOptional<T> {
    case none
    case value(T)

    var value: T? {
        switch self {
        case .none:
            return nil
        case let .value(t):
            return t
        }
    }
}
