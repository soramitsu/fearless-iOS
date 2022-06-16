import Foundation

protocol WalletLocalSubscriptionHandler: AnyObject {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    )
}

extension WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result _: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset _: ChainAsset
    ) {}
}
