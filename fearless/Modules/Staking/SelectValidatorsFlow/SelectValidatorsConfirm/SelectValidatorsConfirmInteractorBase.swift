import Foundation
import RobinHood
import BigInt
import SSFModels

class SelectValidatorsConfirmInteractorBase: SelectValidatorsConfirmInteractorInputProtocol,
    StakingDurationFetching {
    weak var presenter: SelectValidatorsConfirmInteractorOutputProtocol!

    let chainAsset: ChainAsset
    let strategy: SelectValidatorsConfirmStrategy
    let balanceAccountId: AccountId
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol

    init(
        balanceAccountId: AccountId,
        chainAsset: ChainAsset,
        strategy: SelectValidatorsConfirmStrategy,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol

    ) {
        self.chainAsset = chainAsset
        self.strategy = strategy
        self.balanceAccountId = balanceAccountId
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
    }

    // MARK: - SelectValidatorsConfirmInteractorInputProtocol

    func setup() {
        accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: balanceAccountId, handler: self)

        strategy.setup()
        strategy.subscribeToBalance()
    }

    func submitNomination(closure: ExtrinsicBuilderClosure?) {
        strategy.submitNomination(closure: closure)
    }

    func estimateFee(closure: ExtrinsicBuilderClosure?) {
        strategy.estimateFee(closure: closure)
    }
}

extension SelectValidatorsConfirmInteractorBase: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        presenter.didReceiveAccountInfo(result: result)
    }
}
