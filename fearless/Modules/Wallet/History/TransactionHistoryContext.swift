import Foundation

struct TransactionHistoryContext {
    static let cursor = "cursor"
    static let isComplete = "isComplete"

    let cursor: String?
    let isComplete: Bool

    init(
        cursor: String?,
        isComplete: Bool
    ) {
        self.isComplete = isComplete
        self.cursor = cursor
    }
}

extension TransactionHistoryContext {
    init(context: [String: String]) {
        cursor = context[Self.cursor] ?? nil
        isComplete = context[Self.isComplete].map { Bool($0) ?? false } ?? false
    }

    func toContext() -> [String: String] {
        var context = [Self.isComplete: String(isComplete)]

        if let cursor = cursor {
            context[Self.cursor] = cursor
        }

        return context
    }
}
