import Foundation
import SoraKeystore
import RobinHood
import SSFModels

final class StakingAssetSettings: PersistentValueSettings<ChainAsset> {
    let settings: SettingsManagerProtocol
    let operationQueue: OperationQueue
    let wallet: MetaAccountModel

    init(
        storageFacade: StorageFacadeProtocol,
        settings: SettingsManagerProtocol,
        operationQueue: OperationQueue,
        wallet: MetaAccountModel
    ) {
        self.settings = settings
        self.operationQueue = operationQueue
        self.wallet = wallet

        super.init(storageFacade: storageFacade)
    }

    override func performSetup(completionClosure: @escaping (Result<ChainAsset?, Error>) -> Void) {
        let maybeChainAssetId = settings.stakingAsset

        // Relay staking moved to Asset Hub, a parachain, so every chain is a candidate, not only relay chains.
        let factory = ChainRepositoryFactory(storageFacade: storageFacade)
        let repository = AnyDataProviderRepository(factory.createRepository(for: nil))

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let mappingOperation = ClosureOperation<ChainAsset?> { [weak self] in
            let chains = try fetchOperation.extractNoCancellableResultData().filter { !$0.disabled }

            if
                let chainAssetId = maybeChainAssetId,
                let selected = AssetHubStakingRoute.selectedAsset(chainAssetId, in: chains),
                self?.wallet.fetch(for: selected.chain.accountRequest()) != nil {
                if selected.chainAssetId != chainAssetId {
                    self?.settings.stakingAsset = selected.chainAssetId
                }

                return selected
            }

            let assetHubChains = AssetHubStakingRoute.routes.compactMap { route in
                chains.first { $0.chainId == route.stakingChainId }
            }
            let otherChains = chains.filter { AssetHubStakingRoute.staking(on: $0.chainId) == nil }

            let maybeChain = (assetHubChains + otherChains).first { chain in
                chain.assets.contains(where: { $0.staking != nil }) &&
                    self?.wallet.fetch(for: chain.accountRequest()) != nil
            }

            let maybeAsset = maybeChain?.assets.first { $0.staking != nil }

            if let chain = maybeChain, let asset = maybeAsset {
                self?.settings.stakingAsset = ChainAssetId(chainId: chain.chainId, assetId: asset.id)
                return ChainAsset(chain: chain, asset: asset)
            }

            return nil
        }

        mappingOperation.addDependency(fetchOperation)

        // The staking view factory reads `value` immediately after setup. Finish
        // this local database read before publishing the selected asset.
        operationQueue.addOperations([fetchOperation, mappingOperation], waitUntilFinished: true)

        do {
            let result = try mappingOperation.extractNoCancellableResultData()
            completionClosure(.success(result))
        } catch {
            completionClosure(.failure(error))
        }
    }

    override func performSave(
        value: ChainAsset,
        completionClosure: @escaping (Result<ChainAsset, Error>) -> Void
    ) {
        guard AssetHubStakingRoute.migrating(value.chain.chainId) == nil else {
            completionClosure(.failure(StakingServiceFactoryError.stakingUnavailable))
            return
        }

        settings.stakingAsset = ChainAssetId(
            chainId: value.chain.chainId,
            assetId: value.asset.id
        )

        completionClosure(.success(value))
    }
}
