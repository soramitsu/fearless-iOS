import RobinHood
import BigInt
import SSFModels
import Foundation

final class AnalyticsStakeInteractor {
    weak var presenter: AnalyticsStakeInteractorOutputProtocol!

    let stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    private let priceLocalSubscriber: PriceLocalStorageSubscriber

    private let operationManager: OperationManagerProtocol
    private let chainAsset: ChainAsset
    private let selectedAccountAddress: AccountAddress

    private var priceProvider: AnySingleValueProvider<[PriceData]>?
    private var stashItemProvider: StreamableProvider<StashItem>?

    init(
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        operationManager: OperationManagerProtocol,
        selectedAccountAddress: AccountAddress,
        chainAsset: ChainAsset
    ) {
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.priceLocalSubscriber = priceLocalSubscriber
        self.operationManager = operationManager
        self.selectedAccountAddress = selectedAccountAddress
        self.chainAsset = chainAsset
    }
}

extension AnalyticsStakeInteractor: AnalyticsStakeInteractorInputProtocol {
    func setup() {
        priceProvider = priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)

        stashItemProvider = subscribeStashItemProvider(for: selectedAccountAddress)
    }

    func fetchStakeHistory(stashAddress: AccountAddress) {
        guard let analyticsURL = chainAsset.chain.externalApi?.staking?.url else { return }
        let subqueryStakeHistorySource = SubqueryStakeSource(address: stashAddress, url: analyticsURL)
        let fetchOperation = subqueryStakeHistorySource.fetchOperation()

        fetchOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let response = try fetchOperation.targetOperation.extractNoCancellableResultData() ?? []
                    self?.presenter.didReceieve(stakeDataResult: .success(response))
                } catch {
                    self?.presenter.didReceieve(stakeDataResult: .failure(error))
                }
            }
        }
        operationManager.enqueue(operations: fetchOperation.allOperations, in: .transient)
    }
}

extension AnalyticsStakeInteractor: PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        presenter.didReceivePriceData(result: result)
    }
}

extension AnalyticsStakeInteractor: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        presenter.didReceiveStashItem(result: result)
    }
}
