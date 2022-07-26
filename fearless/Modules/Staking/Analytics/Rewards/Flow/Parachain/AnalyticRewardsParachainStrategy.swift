import Foundation
import RobinHood

protocol AnalyticsRewardsParachainStrategyOutput: AnyObject {
    func didReceieveSubqueryData(_ subqueryData: [SubqueryRewardItemData]?)
    func didReceiveError(_ error: Error)
}

final class AnalyticsRewardsParachainStrategy {
    private let operationManager: OperationManagerProtocol
    private let logger: LoggerProtocol?
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private weak var output: AnalyticsRewardsParachainStrategyOutput?

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        output: AnalyticsRewardsParachainStrategyOutput?
    ) {
        self.operationManager = operationManager
        self.logger = logger
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.output = output
    }
}

extension AnalyticsRewardsParachainStrategy: AnalyticsRewardsStrategy {
    func setup() {
        if let address = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            fetchRewards(address: address)
        }
    }

    func fetchRewards(address: AccountAddress) {
        guard let analyticsURL = chainAsset.chain.externalApi?.staking?.url else { return }
        let subqueryRewardsSource = ParachainSubqueryRewardsSource(address: address, url: analyticsURL)
        let fetchOperation = subqueryRewardsSource.fetchOperation()

        fetchOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let response = try fetchOperation.targetOperation.extractNoCancellableResultData()
                    self?.output?.didReceieveSubqueryData(response)
                } catch {
                    self?.output?.didReceiveError(error)
                }
            }
        }
        operationManager.enqueue(operations: fetchOperation.allOperations, in: .transient)
    }
}
