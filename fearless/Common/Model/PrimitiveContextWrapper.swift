import Foundation

final class PrimitiveContextWrapper<T> {
    let value: T

    init(value: T) {
        self.value = value
    }
}
