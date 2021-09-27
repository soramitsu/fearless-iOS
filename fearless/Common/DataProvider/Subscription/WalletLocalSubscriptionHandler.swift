import Foundation

protocol WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id
    )
}

extension WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result _: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {}
}
