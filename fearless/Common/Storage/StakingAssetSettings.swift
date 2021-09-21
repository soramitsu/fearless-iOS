import Foundation
import SoraKeystore
import RobinHood

final class StakingAssetSettings: PersistentValueSettings<ChainAsset> {
    let settings: SettingsManagerProtocol
    let operationQueue: OperationQueue

    init(
        storageFacade: StorageFacadeProtocol,
        settings: SettingsManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.settings = settings
        self.operationQueue = operationQueue

        super.init(storageFacade: storageFacade)
    }

    override func performSetup(completionClosure: @escaping (Result<ChainAsset?, Error>) -> Void) {
        let repository: AnyDataProviderRepository<ChainModel>
        let mapper = AnyCoreDataMapper(ChainModelMapper())

        let maybeChainAssetId = settings.stakingAsset

        if let chainAssetId = maybeChainAssetId {
            let filter = NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate.chainBy(identifier: chainAssetId.chainId),
                NSPredicate.relayChains()
            ])

            repository = AnyDataProviderRepository(
                storageFacade.createRepository(filter: filter, sortDescriptors: [], mapper: mapper)
            )
        } else {
            let filter = NSPredicate.relayChains()
            repository = AnyDataProviderRepository(
                storageFacade.createRepository(filter: filter, sortDescriptors: [], mapper: mapper)
            )
        }

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let mappingOperation = ClosureOperation<ChainAsset?> {
            let chains = try fetchOperation.extractNoCancellableResultData()

            if
                let selectedChain = chains.first(where: { $0.chainId == maybeChainAssetId?.chainId }),
                let selectedAsset = selectedChain.assets.first(where: { $0.assetId == maybeChainAssetId?.assetId }) {
                return ChainAsset(chain: selectedChain, asset: selectedAsset)
            }

            let maybeChain = chains.first { chain in
                chain.assets.contains { $0.staking != nil }
            }

            let maybeAsset = maybeChain?.assets.first { $0.staking != nil }

            if let chain = maybeChain, let asset = maybeAsset {
                self.settings.stakingAsset = ChainAssetId(chainId: chain.chainId, assetId: asset.assetId)
                return ChainAsset(chain: chain, asset: asset)
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
            assetId: value.asset.assetId
        )

        completionClosure(.success(value))
    }
}
