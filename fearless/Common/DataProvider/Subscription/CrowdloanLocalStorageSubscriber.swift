import Foundation
import RobinHood

protocol CrowdloanLocalStorageSubscriber where Self: AnyObject {
    var crowdloanLocalSubscriptionFactory: CrowdloanLocalSubscriptionFactoryProtocol { get }

    var crowdloanLocalSubscriptionHandler: CrowdloanLocalSubscriptionHandler { get }

    func subscribeToBlockNumber(
        for chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedBlockNumber>?

    func subscribeToCrowdloanFunds(
        for paraId: ParaId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedCrowdloanFunds>?
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

    func subscribeToCrowdloanFunds(
        for paraId: ParaId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedCrowdloanFunds>? {
        guard let crowdloanFundsProvider = try? crowdloanLocalSubscriptionFactory.getCrowdloanFundsProvider(
            for: paraId,
            chainId: chainId
        ) else {
            return nil
        }

        let updateClosure: ([DataProviderChange<DecodedCrowdloanFunds>]) -> Void = { [weak self] changes in
            let crowdloanFunds = changes.reduceToLastChange()?.item
            self?.crowdloanLocalSubscriptionHandler.handleCrowdloanFunds(
                result: .success(crowdloanFunds),
                for: paraId,
                chainId: chainId
            )
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.crowdloanLocalSubscriptionHandler.handleCrowdloanFunds(
                result: .failure(error),
                for: paraId,
                chainId: chainId
            )
        }

        let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: false, waitsInProgressSyncOnAdd: false)

        crowdloanFundsProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return crowdloanFundsProvider
    }
}

extension CrowdloanLocalStorageSubscriber where Self: CrowdloanLocalSubscriptionHandler {
    var crowdloanLocalSubscriptionHandler: CrowdloanLocalSubscriptionHandler { self }
}
