import Foundation
import RobinHood

extension SingleValueProviderSubscriber where Self: AnyObject {
    func subscribeToPriceProvider(
        for assetId: WalletAssetId
    ) -> AnySingleValueProvider<PriceData>? {
        let priceProvider = singleValueProviderFactory.getPriceProvider(for: assetId)

        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            let finalValue = changes.reduceToLastChange()
            self?.subscriptionHandler.handlePrice(result: .success(finalValue), for: assetId)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.subscriptionHandler.handlePrice(result: .failure(error), for: assetId)
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        priceProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return priceProvider
    }

    func subscribeToTotalRewardProvider(
        for address: AccountAddress,
        assetId: WalletAssetId
    ) -> AnySingleValueProvider<TotalRewardItem>? {
        guard let totalRewardProvider = try? singleValueProviderFactory
            .getTotalReward(for: address, assetId: assetId)
        else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<TotalRewardItem>]) in
            if let finalValue = changes.reduceToLastChange() {
                self?.subscriptionHandler.handleTotalReward(
                    result: .success(finalValue),
                    address: address,
                    assetId: assetId
                )
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.subscriptionHandler.handleTotalReward(
                result: .failure(error),
                address: address,
                assetId: assetId
            )

            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: true,
            waitsInProgressSyncOnAdd: false
        )

        totalRewardProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        totalRewardProvider.refresh()

        return totalRewardProvider
    }

    func subscribeToAccountInfoProvider(
        for address: AccountAddress,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedAccountInfo>? {
        guard let accountInfoProvider = try? singleValueProviderFactory
            .getAccountProvider(
                for: address,
                runtimeService: runtimeService
            )
        else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedAccountInfo>]) in
            let accountInfo = changes.reduceToLastChange()
            self?.subscriptionHandler.handleAccountInfo(
                result: .success(accountInfo?.item),
                address: address
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.subscriptionHandler.handleAccountInfo(result: .failure(error), address: address)
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        accountInfoProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return accountInfoProvider
    }

    func subscribeToElectionStatusProvider(
        chain: Chain,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedElectionStatus>? {
        guard let electionStatusProvider = try? singleValueProviderFactory
            .getElectionStatusProvider(chain: chain, runtimeService: runtimeService)
        else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedElectionStatus>]) in
            let electionStatus = changes.reduceToLastChange()
            self?.subscriptionHandler.handleElectionStatus(
                result: .success(electionStatus?.item),
                chain: chain
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.subscriptionHandler.handleElectionStatus(result: .failure(error), chain: chain)
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        electionStatusProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return electionStatusProvider
    }

    func subscribeToNominationProvider(
        for address: AccountAddress,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedNomination>? {
        guard let nominatorProvider = try? singleValueProviderFactory
            .getNominationProvider(for: address, runtimeService: runtimeService)
        else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedNomination>]) in
            let nomination = changes.reduceToLastChange()
            self?.subscriptionHandler.handleNomination(
                result: .success(nomination?.item),
                address: address
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.subscriptionHandler.handleNomination(result: .failure(error), address: address)
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        nominatorProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return nominatorProvider
    }

    func subcscribeToValidatorProvider(
        for address: AccountAddress,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedValidator>? {
        guard let validatorProvider = try? singleValueProviderFactory
            .getValidatorProvider(for: address, runtimeService: runtimeService)
        else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedValidator>]) in
            let validator = changes.reduceToLastChange()
            self?.subscriptionHandler.handleValidator(result: .success(validator?.item), address: address)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.subscriptionHandler.handleValidator(result: .failure(error), address: address)
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        validatorProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return validatorProvider
    }

    func subscribeToLedgerInfoProvider(
        for address: AccountAddress,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedLedgerInfo>? {
        guard let ledgerProvider = try? singleValueProviderFactory
            .getLedgerInfoProvider(for: address, runtimeService: runtimeService)
        else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedLedgerInfo>]) in
            let ledgerInfo = changes.reduceToLastChange()
            self?.subscriptionHandler.handleLedgerInfo(
                result: .success(ledgerInfo?.item),
                address: address
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.subscriptionHandler.handleLedgerInfo(result: .failure(error), address: address)
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        ledgerProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return ledgerProvider
    }

    func subscribeToActiveEraProvider(
        for chain: Chain,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedActiveEra>? {
        guard let activeEraProvider = try? singleValueProviderFactory
            .getActiveEra(for: chain, runtimeService: runtimeService)
        else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedActiveEra>]) in
            let activeEra = changes.reduceToLastChange()
            self?.subscriptionHandler.handleActiveEra(result: .success(activeEra?.item), chain: chain)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.subscriptionHandler.handleActiveEra(result: .failure(error), chain: chain)
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        activeEraProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return activeEraProvider
    }

    func subscribeToPayeeProvider(
        for address: AccountAddress,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedPayee>? {
        guard let payeeProvider = try? singleValueProviderFactory
            .getPayee(for: address, runtimeService: runtimeService)
        else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedPayee>]) in
            let payee = changes.reduceToLastChange()
            self?.subscriptionHandler.handlePayee(result: .success(payee?.item), address: address)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.subscriptionHandler.handlePayee(result: .failure(error), address: address)
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        payeeProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return payeeProvider
    }

    func subscribeToBlockNumber(
        for chain: Chain,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedBlockNumber>? {
        guard let blockNumberProvider = try? singleValueProviderFactory
            .getBlockNumber(for: chain, runtimeService: runtimeService)
        else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedBlockNumber>]) in
            let blockNumber = changes.reduceToLastChange()
            self?.subscriptionHandler.handleBlockNumber(
                result: .success(blockNumber?.item?.value),
                chain: chain
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.subscriptionHandler.handleBlockNumber(result: .failure(error), chain: chain)
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

    func subscribeToMinNominatorBondProvider(
        chain: Chain,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> AnyDataProvider<DecodedMinNominatorBond>? {
        guard let minBondProvider = try? singleValueProviderFactory
            .getMinNominatorBondProvider(chain: chain, runtimeService: runtimeService) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedMinNominatorBond>]) in
            let minNominatorBond = changes.reduceToLastChange()
            self?.subscriptionHandler.handleMinNominatorBond(
                result: .success(minNominatorBond?.item?.value),
                chain: chain
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.subscriptionHandler.handleMinNominatorBond(result: .failure(error), chain: chain)
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        minBondProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return minBondProvider
    }
}

extension SingleValueProviderSubscriber where Self: SingleValueSubscriptionHandler {
    var subscriptionHandler: SingleValueSubscriptionHandler { self }
}
