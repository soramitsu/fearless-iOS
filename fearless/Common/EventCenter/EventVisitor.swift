import Foundation

protocol EventVisitorProtocol: AnyObject {
    func processSelectedAccountChanged(event: SelectedAccountChanged)
    func processSelectedUsernameChanged(event: SelectedUsernameChanged)
    func processSelectedConnectionChanged(event: SelectedConnectionChanged)
    func processBalanceChanged(event: WalletBalanceChanged)
    func processStakingChanged(event: WalletStakingInfoChanged)
    func processNewTransaction(event: WalletNewTransactionInserted)
    func processPurchaseCompletion(event: PurchaseCompleted)
    func processTypeRegistryPrepared(event: TypeRegistryPrepared)
    func processEraStakersInfoChanged(event: EraStakersInfoChanged)
    func processWalletNameChanged(event: WalletNameChanged)

    func processChainSyncDidStart(event: ChainSyncDidStart)
    func processChainSyncDidComplete(event: ChainSyncDidComplete)
    func processChainSyncDidFail(event: ChainSyncDidFail)
    func processChainsUpdated(event: ChainsUpdatedEvent)
    func processChainReconnecting(event: ChainReconnectingEvent)

    func processRuntimeChainsTypesSyncCompleted(event: RuntimeChainsTypesSyncCompleted)
    func processRuntimeChainMetadataSyncCompleted(event: RuntimeMetadataSyncCompleted)

    func processUserInactive(event: UserInactiveEvent)

    func processMetaAccountChanged(event: MetaAccountModelChangedEvent)
    func processStakingUpdatedEvent()
    func processZeroBalancesSettingChanged()

    func processKYCShouldRestart()
    func processKYCUserStatusChanged()
    func processKYCTokenChanged(token: SCToken)
    func processKYCTokenNeedRefresh(token: SCToken)
}

extension EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {}
    func processSelectedConnectionChanged(event _: SelectedConnectionChanged) {}
    func processBalanceChanged(event _: WalletBalanceChanged) {}
    func processStakingChanged(event _: WalletStakingInfoChanged) {}
    func processNewTransaction(event _: WalletNewTransactionInserted) {}
    func processSelectedUsernameChanged(event _: SelectedUsernameChanged) {}
    func processPurchaseCompletion(event _: PurchaseCompleted) {}
    func processTypeRegistryPrepared(event _: TypeRegistryPrepared) {}
    func processEraStakersInfoChanged(event _: EraStakersInfoChanged) {}
    func processWalletNameChanged(event _: WalletNameChanged) {}

    func processChainSyncDidStart(event _: ChainSyncDidStart) {}
    func processChainSyncDidComplete(event _: ChainSyncDidComplete) {}
    func processChainSyncDidFail(event _: ChainSyncDidFail) {}
    func processChainsUpdated(event _: ChainsUpdatedEvent) {}
    func processChainReconnecting(event _: ChainReconnectingEvent) {}

    func processRuntimeChainsTypesSyncCompleted(event _: RuntimeChainsTypesSyncCompleted) {}
    func processRuntimeChainMetadataSyncCompleted(event _: RuntimeMetadataSyncCompleted) {}

    func processUserInactive(event _: UserInactiveEvent) {}

    func processMetaAccountChanged(event _: MetaAccountModelChangedEvent) {}
    func processStakingUpdatedEvent() {}
    func processZeroBalancesSettingChanged() {}

    func processKYCShouldRestart() {}
    func processKYCUserStatusChanged() {}
    func processKYCTokenChanged(token _: SCToken) {}
    func processKYCTokenNeedRefresh(token _: SCToken) {}
}
