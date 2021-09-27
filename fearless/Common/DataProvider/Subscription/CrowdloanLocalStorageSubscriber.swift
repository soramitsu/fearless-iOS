import Foundation
import RobinHood

protocol CrowdloanLocalStorageSubscriber where Self: AnyObject {
    var crowdloanLocalSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol { get }

    var crowdloanLocalSubscriptionHandler: CrowdloanLocalSubscriptionHandler { get }

    func subscribeToBlockNumber(
        for chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedBlockNumber>?
}

extension CrowdloanLocalStorageSubscriber {
    func subscribeToBlockNumber(
        for chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedBlockNumber>? {
        guard let blockNumberProvider = try? crowdloanLocalSubscriptionFactory.getBlockNumberProvider(
            for: chainId
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedBlockNumber>]) in
            let blockNumber = changes.reduceToLastChange()
            self?.crowdloanLocalSubscriptionHandler.handleBlockNumber(
                result: .success(blockNumber?.item?.value),
                chainId: chainId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.crowdloanLocalSubscriptionHandler.handleBlockNumber(
                result: .failure(error), chainId: chainId
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        blockNumberProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return blockNumberProvider
    }
}

extension CrowdloanLocalStorageSubscriber where Self: CrowdloanLocalSubscriptionHandler {
    var crowdloanLocalSubscriptionHandler: CrowdloanLocalSubscriptionHandler { self }
}
