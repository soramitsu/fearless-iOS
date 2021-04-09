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

    init(
        page: Int,
        row: Int,
        isComplete: Bool,
        keySuffix: String
    ) {
        self.page = page
        self.row = row
        self.isComplete = isComplete
        self.keySuffix = keySuffix
    }

    func toContext() -> [String: String] {
        [
            Self.pageKey + keySuffix: String(page),
            Self.rowKey + keySuffix: String(row),
            Self.completeKey + keySuffix: String(isComplete)
        ]
    }

    func byReplacingPage(_ newPage: Int) -> TransactionHistorySourceContext {
        TransactionHistorySourceContext(
            page: newPage,
            row: row,
            isComplete: isComplete,
            keySuffix: keySuffix
        )
    }

    func byReplacingRow(_ newRow: Int) -> TransactionHistorySourceContext {
        TransactionHistorySourceContext(
            page: page,
            row: newRow,
            isComplete: isComplete,
            keySuffix: keySuffix
        )
    }

    func byReplacingCompletion(_ newCompletion: Bool) -> TransactionHistorySourceContext {
        TransactionHistorySourceContext(
            page: page,
            row: row,
            isComplete: newCompletion,
            keySuffix: keySuffix
        )
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
            result.merging(item.toContext()) { str1, _ in str1 }
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

    func sourceContext(for label: WalletRemoteHistorySourceLabel) -> TransactionHistorySourceContext {
        switch label {
        case .transfers:
            return transfers
        case .rewards:
            return rewards
        case .extrinsics:
            return extrinsics
        }
    }

    func byReplacingSource(
        context: TransactionHistorySourceContext,
        for label: WalletRemoteHistorySourceLabel
    ) -> TransactionHistoryContext {
        switch label {
        case .transfers:
            return byReplacingTransfers(context)
        case .rewards:
            return byReplacingRewards(context)
        case .extrinsics:
            return byReplacingExtrinsics(context)
        }
    }

    func byApplying(filter: WalletHistoryFilter) -> TransactionHistoryContext {
        WalletRemoteHistorySourceLabel.allCases.reduce(self) { context, source in
            context.byApplyingIfNeeded(filter: filter, for: source)
        }
    }

    private func byApplyingIfNeeded(
        filter: WalletHistoryFilter,
        for label: WalletRemoteHistorySourceLabel
    ) -> TransactionHistoryContext {
        switch label {
        case .transfers:
            if !filter.contains(.transfers) {
                return byReplacingTransfers(transfers.byReplacingCompletion(true))
            } else {
                return self
            }
        case .rewards:
            if !filter.contains(.rewardsAndSlashes) {
                return byReplacingRewards(rewards.byReplacingCompletion(true))
            } else {
                return self
            }
        case .extrinsics:
            if !filter.contains(.extrinsics) {
                return byReplacingExtrinsics(extrinsics.byReplacingCompletion(true))
            } else {
                return self
            }
        }
    }
}
