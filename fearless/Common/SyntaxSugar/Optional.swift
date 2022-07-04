import Foundation

// MARK: - Base

extension Optional {
    func or(_ value: Wrapped) -> Wrapped {
        if let value = self {
            return value
        }

        return value
    }
}

extension Optional where Wrapped: Emptyable {
    func orEmpty() -> Wrapped {
        or(Wrapped.empty())
    }

    var isEmptyOrNil: Bool {
        orEmpty().isEmpty
    }

    var isNotEmptyAndNil: Bool {
        !isEmptyOrNil
    }
}

// MARK: - Bool

extension Optional where Wrapped == Bool {
    func orFalse() -> Bool {
        or(false)
    }

    func orTrue() -> Bool {
        or(true)
    }
}

// MARK: - Data

extension Optional where Wrapped == Data {
    func orEmptyJsonArray() -> Data {
        or("[]".data(using: .utf8)!)
    }

    func orEmptyJsonObject() -> Data {
        or("{}".data(using: .utf8)!)
    }
}
