import Foundation

struct TransactionHistoryContext {
    static let transfersPageKey = "history.page.transfers"
    static let transfersCompleteKey = "history.complete.transfers"
    static let rewardsPageKey = "history.page.rewards"
    static let rewardsCompleteKey = "history.complete.rewards"

    let transfersPage: Int
    let isTransfersComplete: Bool
    let rewardsPage: Int
    let isRewardsComplete: Bool

    var isComplete: Bool { isTransfersComplete && isRewardsComplete }
}

extension TransactionHistoryContext {
    init(context: [String: String]) {
        transfersPage = TransactionHistoryContext.extractPage(
            for: TransactionHistoryContext.transfersPageKey,
            from: context
        )

        isTransfersComplete = TransactionHistoryContext.extractCompleteness(
            for: TransactionHistoryContext.transfersCompleteKey,
            from: context
        )

        rewardsPage = TransactionHistoryContext.extractPage(
            for: TransactionHistoryContext.rewardsPageKey,
            from: context
        )

        isRewardsComplete = TransactionHistoryContext.extractCompleteness(
            for: TransactionHistoryContext.rewardsCompleteKey,
            from: context
        )
    }

    func toContext() -> [String: String] {
        [
            TransactionHistoryContext.transfersPageKey: String(transfersPage),
            TransactionHistoryContext.transfersCompleteKey: String(isTransfersComplete),
            TransactionHistoryContext.rewardsPageKey: String(rewardsPage),
            TransactionHistoryContext.rewardsCompleteKey: String(isRewardsComplete)
        ]
    }

    private static func extractPage(for key: String, from context: [String: String]) -> Int {
        if let pageString = context[key], let page = Int(pageString) {
            return page
        } else {
            return 0
        }
    }

    private static func extractCompleteness(for key: String, from context: [String: String]) -> Bool {
        if let completeString = context[key], let isComplete = Bool(completeString) {
            return isComplete
        } else {
            return false
        }
    }
}
