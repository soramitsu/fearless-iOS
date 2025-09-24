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
            guard let self else { return }
            let fetchCollectionsOperation = self.operationFactory.fetchCollections(
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

            self.operationQueue.addOperations(fetchCollectionsOperation.allOperations, waitUntilFinished: true)
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
            guard let self else { return }
            let fetchNftsOperation = self.operationFactory.fetchNFTs(
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

            self.operationQueue.addOperations(fetchNftsOperation.allOperations, waitUntilFinished: false)
        }
    }

    private func fetchCollectionNfts(
        for chain: ChainModel,
        address: String,
        nextId: String?
    ) async throws -> NFTBatch? {
        try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let strongSelf = self else {
                continuation.resume(with: .success(NFTBatch(nfts: [], nextTokenId: nil)))
                return
            }

            let fetchNftsOperation = strongSelf.operationFactory.fetchCollectionNfts(
                chain: chain,
                address: address,
                nextId: nextId
            )

            fetchNftsOperation.targetOperation.completionBlock = { [weak self] in
                do {
                    let nftBatch = try fetchNftsOperation.targetOperation.extractNoCancellableResultData()
                    continuation.resume(with: .success(nftBatch))
                } catch {
                    self?.logger.error(error.localizedDescription)
                    continuation.resume(with: .success(NFTBatch(nfts: [], nextTokenId: nil)))
                }
            }

            self?.operationQueue.addOperations(fetchNftsOperation.allOperations, waitUntilFinished: false)
        }
    }

    private func fetchOwners(
        for chain: ChainModel,
        address: String,
        tokenId: String
    ) async throws -> [String]? {
        try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let strongSelf = self else {
                continuation.resume(with: .success([]))
                return
            }

            let fetchOwnersOperation = strongSelf.operationFactory.fetchOwners(
                for: chain,
                address: address,
                tokenId: tokenId
            )

            fetchOwnersOperation.targetOperation.completionBlock = { [weak self] in
                do {
                    let owners = try fetchOwnersOperation.targetOperation.extractNoCancellableResultData()
                    continuation.resume(with: .success(owners))
                } catch {
                    self?.logger.error(error.localizedDescription)
                    continuation.resume(with: .success([]))
                }
            }

            self?.operationQueue.addOperations(fetchOwnersOperation.allOperations, waitUntilFinished: false)
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
        nextId: String?
    ) async throws -> NFTBatch {
        let nfts = try await withThrowingTaskGroup(of: NFTBatch.self) { [weak self] _ in
            guard let strongSelf = self else {
                return NFTBatch(nfts: [], nextTokenId: nil)
            }

            let result = try await strongSelf.fetchCollectionNfts(
                for: chain,
                address: collectionAddress,
                nextId: nextId
            )
            return result ?? NFTBatch(nfts: [], nextTokenId: nil)
        }
        return nfts
    }

    func fetchOwners(
        for address: String,
        tokenId: String,
        chain: ChainModel
    ) async throws -> [String] {
        let owners: [String] = try await withThrowingTaskGroup(of: [String].self) { [weak self] _ in
            guard let strongSelf = self else {
                return []
            }

            let result = try await strongSelf.fetchOwners(
                for: chain,
                address: address,
                tokenId: tokenId
            )
            return result ?? []
        }
        return owners
    }
}
