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

// MARK: - Bool

extension Optional where Wrapped == Bool {
    func orFalse() -> Bool {
        or(false)
    }

    func orTrue() -> Bool {
        or(true)
    }
}

// MARK: - isNullOrEmpty

protocol StringType {
    var isEmpty: Bool { get }
}

extension String: StringType {}

extension Optional where Wrapped: StringType {
    var isNullOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}

extension Optional where Wrapped: Collection {
    var isNullOrEmpty: Bool {
        self?.isEmpty ?? true
    }
}
