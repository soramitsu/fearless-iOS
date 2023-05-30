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
        let filter: NSPredicate
        let maybeChainAssetId = settings.stakingAsset

        if let chainAssetId = maybeChainAssetId {
            filter = NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate.chainBy(identifier: chainAssetId.chainId),
                NSPredicate.relayChains()
            ])
        } else {
            filter = NSPredicate.relayChains()
        }

        let factory = ChainRepositoryFactory(storageFacade: storageFacade)
        let repository = AnyDataProviderRepository(factory.createRepository(for: filter))

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let mappingOperation = ClosureOperation<ChainAsset?> { [weak self] in
            let chains = try fetchOperation.extractNoCancellableResultData()

            if
                let selectedChain = chains.first(where: { $0.chainId == maybeChainAssetId?.chainId }),
                let selectedAsset = selectedChain.assets.first(where: { $0.assetId == maybeChainAssetId?.assetId }),
                self?.wallet.fetch(for: selectedChain.accountRequest()) != nil {
                return ChainAsset(chain: selectedChain, asset: selectedAsset.asset)
            }

            let maybeChain = chains.first { chain in
                chain.assets.contains { $0.staking != nil } && self?.wallet.fetch(for: chain.accountRequest()) != nil
            }

            let maybeAsset = maybeChain?.assets.first { $0.staking != nil }

            if let chain = maybeChain, let asset = maybeAsset {
                self?.settings.stakingAsset = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)
                return ChainAsset(chain: chain, asset: asset.asset)
            }

            return nil
        }

        mappingOperation.addDependency(fetchOperation)

        mappingOperation.completionBlock = {
            do {
                let result = try mappingOperation.extractNoCancellableResultData()
                completionClosure(.success(result))
            } catch {
                completionClosure(.failure(error))
            }
        }

        operationQueue.addOperations([fetchOperation, mappingOperation], waitUntilFinished: false)
    }

    override func performSave(
        value: ChainAsset,
        completionClosure: @escaping (Result<ChainAsset, Error>) -> Void
    ) {
        settings.stakingAsset = ChainAssetId(
            chainId: value.chain.chainId,
            assetId: value.asset.id
        )

        completionClosure(.success(value))
    }
}
