import Foundation
import SSFModels

final class EthereumBalanceSubscription {
    private let wallet: MetaAccountModel
    private let accountInfoFetching: EthereumAccountInfoFetching

    weak var handler: AccountInfoSubscriptionAdapterHandler?
    private var timer: Timer?

    init(
        wallet: MetaAccountModel,
        accountInfoFetching: EthereumAccountInfoFetching
    ) {
        self.wallet = wallet
        self.accountInfoFetching = accountInfoFetching
    }

    func subscribe(chainAssets: [ChainAsset]) {
        DispatchQueue.main.async { [weak self] in
            self?.timer = Timer(timeInterval: 30.0, repeats: true, block: { _ in
                chainAssets.filter { $0.chain.isEthereum }.forEach { chainAsset in
                    if let accountId = self?.wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
                        self?.accountInfoFetching.fetch(
                            for: chainAsset,
                            accountId: accountId
                        ) { [weak self] chainAsset, accountInfo in
                            self?.handler?.handleAccountInfo(
                                result: .success(accountInfo),
                                accountId: accountId,
                                chainAsset: chainAsset
                            )
                        }
                    }
                }
            })
            self?.timer?.tolerance = 3.0
            self?.timer?.fire()

            if let timer = self?.timer {
                RunLoop.current.add(timer, forMode: .common)
            }
        }
    }

    func unsubsribe() {
        timer?.invalidate()
    }
}
