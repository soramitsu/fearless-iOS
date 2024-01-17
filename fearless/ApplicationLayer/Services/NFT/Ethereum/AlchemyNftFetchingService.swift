import Foundation
import SSFModels
import RobinHood

final class AlchemyNftFetchingService: BaseNftFetchingService {
    private let operationFactory: AlchemyNFTOperationFactory
    private let logger: LoggerProtocol

    init(
        operationFactory: AlchemyNFTOperationFactory,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.operationFactory = operationFactory
        self.logger = logger

        super.init(chainRepository: chainRepository, operationQueue: operationQueue)
    }

    private func fetchCollections(
        for chain: ChainModel,
        wallet: MetaAccountModel,
        excludeFilters: [NftCollectionFilter]
    ) async throws -> [NFTCollection]? {
        guard let address = wallet.fetch(for: chain.accountRequest())?.toAddress() else {
            throw AddressFactoryError.unexpectedAddress
        }

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            let fetchCollectionsOperation = operationFactory.fetchCollections(
                chain: chain,
                address: address,
                excludeFilters: excludeFilters
            )

            fetchCollectionsOperation.targetOperation.completionBlock = { [weak self] in
                do {
                    let collections = try fetchCollectionsOperation.targetOperation.extractNoCancellableResultData()
                    continuation.resume(with: .success(collections))
                } catch {
                    self?.logger.error(error.localizedDescription)
                    continuation.resume(with: .success([]))
                }
            }

            self?.operationQueue.addOperations(fetchCollectionsOperation.allOperations, waitUntilFinished: true)
        }
    }

    private func fetchNfts(
        for chain: ChainModel,
        wallet: MetaAccountModel,
        excludeFilters: [NftCollectionFilter]
    ) async throws -> [NFT]? {
        guard let address = wallet.fetch(for: chain.accountRequest())?.toAddress() else {
            throw ConvenienceError(error: "Cannot fetch address from chain account")
        }

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            let fetchNftsOperation = operationFactory.fetchNFTs(
                chain: chain,
                address: address,
                excludeFilters: excludeFilters
            )

            fetchNftsOperation.targetOperation.completionBlock = { [weak self] in
                do {
                    let nfts = try fetchNftsOperation.targetOperation.extractNoCancellableResultData()
                    continuation.resume(with: .success(nfts))
                } catch {
                    self?.logger.error(error.localizedDescription)
                    continuation.resume(with: .success([]))
                }
            }

            self?.operationQueue.addOperations(fetchNftsOperation.allOperations, waitUntilFinished: false)
        }
    }

    private func fetchCollectionNfts(
        for chain: ChainModel,
        address: String,
        lastId: String?
    ) async throws -> [NFT]? {
        try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let strongSelf = self else {
                continuation.resume(with: .success([]))
                return
            }

            let fetchNftsOperation = strongSelf.operationFactory.fetchCollectionNfts(
                chain: chain,
                address: address,
                lastId: lastId
            )

            fetchNftsOperation.targetOperation.completionBlock = { [weak self] in
                do {
                    let nfts = try fetchNftsOperation.targetOperation.extractNoCancellableResultData()
                    continuation.resume(with: .success(nfts))
                } catch {
                    self?.logger.error(error.localizedDescription)
                    continuation.resume(with: .success([]))
                }
            }

            self?.operationQueue.addOperations(fetchNftsOperation.allOperations, waitUntilFinished: false)
        }
    }
}

extension AlchemyNftFetchingService: NFTFetchingServiceProtocol {
    func fetchNfts(
        for wallet: MetaAccountModel,
        excludeFilters: [NftCollectionFilter],
        chains: [ChainModel]?
    ) async throws -> [NFT] {
        var requiredChains: [ChainModel]?
        let supportedChains = try await fetchSupportedChains()
        if let selectedChains = chains, selectedChains.isNotEmpty {
            requiredChains = selectedChains.filter { chain in
                supportedChains.contains(chain)
            }
        } else {
            requiredChains = supportedChains
        }

        guard let chains = requiredChains else {
            return []
        }

        let nfts = try await withThrowingTaskGroup(of: [NFT]?.self) { [weak self] group in
            guard let strongSelf = self else {
                return [NFT]()
            }

            for chain in chains {
                group.addTask {
                    let nfts = try await strongSelf.fetchNfts(
                        for: chain,
                        wallet: wallet,
                        excludeFilters: excludeFilters
                    )
                    return nfts
                }
            }

            var result: [NFT] = []

            for try await nfts in group {
                if let nfts = nfts {
                    result.append(contentsOf: nfts)
                }
            }

            return result
        }

        return nfts
    }

    func fetchCollections(
        for wallet: MetaAccountModel,
        excludeFilters: [NftCollectionFilter],
        chains: [ChainModel]?
    ) async throws -> [NFTCollection] {
        var requiredChains: [ChainModel]?
        let supportedChains = try await fetchSupportedChains()
        if let selectedChains = chains, selectedChains.isNotEmpty {
            requiredChains = selectedChains.filter { chain in
                supportedChains.contains(chain)
            }
        } else {
            requiredChains = supportedChains
        }

        guard let chains = requiredChains else {
            return []
        }

        let collections = try await withThrowingTaskGroup(of: [NFTCollection]?.self) { [weak self] group in
            guard let strongSelf = self else {
                return [NFTCollection]()
            }

            for chain in chains {
                group.addTask {
                    let collections = try await strongSelf.fetchCollections(
                        for: chain,
                        wallet: wallet,
                        excludeFilters: excludeFilters
                    )
                    return collections
                }
            }

            var result: [NFTCollection] = []

            for try await collection in group {
                if let collection = collection {
                    result.append(contentsOf: collection)
                }
            }

            return result
        }

        return collections
    }

    func fetchCollectionNfts(
        collectionAddress: String,
        chain: ChainModel,
        lastId: String?
    ) async throws -> [NFT] {
        let nfts = try await withThrowingTaskGroup(of: [NFT].self) { [weak self] _ in
            guard let strongSelf = self else {
                return [NFT]()
            }

            let result = try await strongSelf.fetchCollectionNfts(
                for: chain,
                address: collectionAddress,
                lastId: lastId
            )
            return result ?? []
        }
        return nfts
    }
}
