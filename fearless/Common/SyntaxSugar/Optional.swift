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
