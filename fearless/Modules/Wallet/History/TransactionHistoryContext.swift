import Foundation

struct TransactionHistorySourceContext {
    static let pageKey = "history.page"
    static let rowKey = "history.row"
    static let completeKey = "history.complete"

    let page: Int
    let row: Int
    let isComplete: Bool
    let keySuffix: String

    init(context: [String: String], defaultRow: Int, keySuffix: String) {
        self.keySuffix = keySuffix
        page = Self.extract(for: Self.pageKey + keySuffix, from: context, defaultValue: 0)
        row = Self.extract(for: Self.rowKey + keySuffix, from: context, defaultValue: defaultRow)
        isComplete = Self.extract(for: Self.completeKey + keySuffix, from: context, defaultValue: false)
    }

    func toContext() -> [String: String] {
        [
            Self.pageKey + keySuffix: String(page),
            Self.rowKey + keySuffix: String(row),
            Self.completeKey + keySuffix: String(isComplete)
        ]
    }

    private static func extract<T: LosslessStringConvertible>(
        for key: String,
        from context: [String: String],
        defaultValue: T
    ) -> T {
        if let completeString = context[key], let value = T(completeString) {
            return value
        } else {
            return defaultValue
        }
    }
}

struct TransactionHistoryContext {
    static let transfersSuffix = ".transfers"
    static let rewardsSuffix = ".rewards"
    static let extrinsicsSuffix = ".extrinsics"

    let transfers: TransactionHistorySourceContext
    let rewards: TransactionHistorySourceContext
    let extrinsics: TransactionHistorySourceContext
    let defaultRow: Int

    var isComplete: Bool { transfers.isComplete && rewards.isComplete && extrinsics.isComplete }

    init(
        transfers: TransactionHistorySourceContext,
        rewards: TransactionHistorySourceContext,
        extrinsics: TransactionHistorySourceContext,
        defaultRow: Int
    ) {
        self.transfers = transfers
        self.rewards = rewards
        self.extrinsics = extrinsics
        self.defaultRow = defaultRow
    }
}

extension TransactionHistoryContext {
    init(context: [String: String], defaultRow: Int) {
        self.defaultRow = defaultRow

        transfers = TransactionHistorySourceContext(
            context: context,
            defaultRow: defaultRow,
            keySuffix: Self.transfersSuffix
        )

        rewards = TransactionHistorySourceContext(
            context: context,
            defaultRow: defaultRow,
            keySuffix: Self.rewardsSuffix
        )

        extrinsics = TransactionHistorySourceContext(
            context: context,
            defaultRow: defaultRow,
            keySuffix: Self.extrinsicsSuffix
        )
    }

    func toContext() -> [String: String] {
        [transfers, rewards, extrinsics].reduce([String: String]()) { result, item in
            result.merging(item.toContext()) { s1, _ in s1 }
        }
    }

    func byReplacingTransfers(_ value: TransactionHistorySourceContext) -> TransactionHistoryContext {
        TransactionHistoryContext(
            transfers: value,
            rewards: rewards,
            extrinsics: extrinsics,
            defaultRow: defaultRow
        )
    }

    func byReplacingRewards(_ value: TransactionHistorySourceContext) -> TransactionHistoryContext {
        TransactionHistoryContext(
            transfers: transfers,
            rewards: value,
            extrinsics: extrinsics,
            defaultRow: defaultRow
        )
    }

    func byReplacingExtrinsics(_ value: TransactionHistorySourceContext) -> TransactionHistoryContext {
        TransactionHistoryContext(
            transfers: transfers,
            rewards: rewards,
            extrinsics: value,
            defaultRow: defaultRow
        )
    }
}
