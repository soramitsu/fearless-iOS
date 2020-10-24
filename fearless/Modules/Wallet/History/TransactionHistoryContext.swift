import Foundation

struct TransactionHistoryContext {
    static let pageKey = "history.page"
    static let completeKey = "history.complete"

    let page: Int
    let isComplete: Bool
}

extension TransactionHistoryContext {
    init(context: [String: String]) {
        if let pageString = context[TransactionHistoryContext.pageKey],
           let page = Int(pageString) {
            self.page = page
        } else {
            self.page = 0
        }

        if let completeString = context[TransactionHistoryContext.completeKey],
           let isComplete = Bool(completeString) {
            self.isComplete = isComplete
        } else {
            self.isComplete = false
        }
    }

    func toContext() -> [String: String] {
        [
            TransactionHistoryContext.pageKey: String(page),
            TransactionHistoryContext.completeKey: String(isComplete)
        ]
    }
}
