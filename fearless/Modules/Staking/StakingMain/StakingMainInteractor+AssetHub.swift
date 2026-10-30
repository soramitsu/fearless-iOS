import Foundation
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils

/// On Asset Hub the unbonding period depends on the account: a nominator that was not a validator in the bonding
/// window unbonds after the fast duration. The network info shown for such a chain is completed for one account.
enum AssetHubNetworkStakingInfo {
    static func wrapper(
        _ base: CompoundOperationWrapper<NetworkStakingInfo>,
        chainId: ChainModel.Id,
        accountId: AccountId?,
        runtime: RuntimeCodingServiceProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationManager: OperationManagerProtocol
    ) throws -> CompoundOperationWrapper<NetworkStakingInfo> {
        guard AssetHubStakingRoute.staking(on: chainId) != nil else { return base }
        guard let accountId = accountId else { throw PersistentValueSettingsError.missingValue }
        guard let connection = chainRegistry.getConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }
        let clock = StakingRuntimeClock(
            runtime: { [chainRegistry] in chainRegistry.getRuntimeProvider(for: $0) },
            connection: { [chainRegistry] in chainRegistry.getConnection(for: $0) }
        )
        let factory = AssetHubUnbondingOperationFactory(
            storage: StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: operationManager),
            duration: StakingDurationOperationFactory(clock: clock)
        )
        let duration = factory.create(accountId: accountId, runtime: runtime, connection: connection)
        return factory.applying(duration: duration, to: base)
    }
}

extension StakingMainInteractor {
    func provideNetworkStakingInfo() {
        guard let chainId = selectedChainAsset?.chain.chainId, let eraInfoOperationFactory = eraInfoOperationFactory else {
            return
        }

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            presenter?.didReceive(networkStakingInfoError: ChainRegistryError.runtimeMetadaUnavailable)
            return
        }

        let base = eraInfoOperationFactory.networkStakingOperation(
            for: sharedState.eraValidatorService,
            runtimeService: runtimeService
        )
        let wrapper: CompoundOperationWrapper<NetworkStakingInfo>
        do {
            wrapper = try accountNetworkStakingInfo(base, chainId: chainId, runtime: runtimeService)
        } catch {
            presenter?.didReceive(networkStakingInfoError: error)
            return
        }

        // Asset Hub's unbonding period is read for one account and is requested again after a wallet switch, so a
        // result for the previous account is dropped there. Elsewhere the network info does not depend on the account.
        let accountSpecific = AssetHubStakingRoute.staking(on: chainId) != nil
        let requestedAccountId = selectedAccount?.accountId
        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard
                    self?.selectedChainAsset?.chain.chainId == chainId,
                    !accountSpecific || self?.selectedAccount?.accountId == requestedAccountId
                else {
                    return
                }

                do {
                    let info = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(networkStakingInfo: info)
                } catch {
                    self?.presenter?.didReceive(networkStakingInfoError: error)
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }

    func accountNetworkStakingInfo(
        _ base: CompoundOperationWrapper<NetworkStakingInfo>,
        chainId: ChainModel.Id,
        runtime: RuntimeCodingServiceProtocol
    ) throws -> CompoundOperationWrapper<NetworkStakingInfo> {
        try AssetHubNetworkStakingInfo.wrapper(
            base,
            chainId: chainId,
            accountId: selectedAccount?.accountId,
            runtime: runtime,
            chainRegistry: chainRegistry,
            operationManager: operationManager
        )
    }
}
