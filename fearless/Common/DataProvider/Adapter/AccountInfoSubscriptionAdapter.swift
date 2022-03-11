import Foundation
import RobinHood

protocol AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id
    )
}

class AccountInfoSubscriptionAdapter: WalletLocalStorageSubscriber {
    var walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    
    private var accountInfoProviders: [AnyDataProvider<DecodedAccountInfo>]?
    private var ormlAccountInfoProviders: [AnyDataProvider<DecodedOrmlAccountInfo>]?
    
    init(walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol) {
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
    }
  
    func subscribe(chains: [ChainModel], accountId: AccountId) {
        chains.forEach { chain in
            if chain.isOrml {
                if let provider = subscribeToOrmlAccountInfoProvider(for: accountId, chain: chain)
            }
        }
    }
}

extension AccountInfoSubscriptionAdapter: WalletLocalSubscriptionHandler {
    
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId: ChainModel.Id
    ) {
//        presenter?.didReceiveAccountInfo(result: result, for: chainId)
    }
}

