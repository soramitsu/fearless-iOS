import Foundation

protocol WalletRemoteHistoryFiltering {
    func includes(item: WalletRemoteHistoryItemProtocol) -> Bool
}

final class WalletRemoteHistoryClosureFilter: WalletRemoteHistoryFiltering {
    let block: (WalletRemoteHistoryItemProtocol) -> Bool

    init(block: @escaping (WalletRemoteHistoryItemProtocol) -> Bool) {
        self.block = block
    }

    func includes(item: WalletRemoteHistoryItemProtocol) -> Bool {
        block(item)
    }
}

extension WalletRemoteHistoryClosureFilter {
    static var transfersInExtrinsics: WalletRemoteHistoryClosureFilter {
        let module = "balances"
        let calls = ["transfer", "transfer_keep_alive", "force_transfer"]

        return WalletRemoteHistoryClosureFilter { item in
            guard let extrinsic = item as? SubscanExtrinsicItemData else {
                return true
            }

            return !(extrinsic.callModule.lowercased() == module &&
                calls.contains(extrinsic.callFunction.lowercased()))
        }
    }
}
