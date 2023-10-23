import Foundation
import SSFModels
import RobinHood

final class AlchemyNftFetchingService: BaseNftFetchingService {
    private let operationFactory: AlchemyNFTOperationFactory

    init(
        operationFactory: AlchemyNFTOperationFactory,
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.operationFactory = operationFactory

        super.init(chainRepository: chainRepository, operationQueue: operationQueue)
    }

    private func fetchCollections(for chain: ChainModel, wallet: MetaAccountModel) async throws -> [NFTCollection]? {
        guard let address = wallet.fetch(for: chain.accountRequest())?.toAddress() else {
            throw AddressFactoryError.unexpectedAddress
        }

        return try await withCheckedThrowingContinuation { continuation in
            let fetchNftsOperation = operationFactory.fetchCollections(chain: chain, address: address)

            fetchNftsOperation.targetOperation.completionBlock = {
                do {
                    let collections = try fetchNftsOperation.targetOperation.extractNoCancellableResultData()
                    continuation.resume(with: .success(collections))
                } catch {
                    continuation.resume(with: .failure(error))
                }
            }

            self.operationQueue.addOperations(fetchNftsOperation.allOperations, waitUntilFinished: true)
        }
    }

    private func fetchNfts(for chain: ChainModel, wallet: MetaAccountModel) async throws -> [NFT]? {
        guard let address = wallet.fetch(for: chain.accountRequest())?.toAddress() else {
            throw AddressFactoryError.unexpectedAddress
        }

        return nil
//        return try await withCheckedThrowingContinuation { continuation in
//            let fetchNftsOperation = operationFactory.fetchNFTs(chain: chain, address: address)
//
//            fetchNftsOperation.targetOperation.completionBlock = {
//                do {
//                    let nfts = try fetchNftsOperation.targetOperation.extractNoCancellableResultData()
//                    continuation.resume(with: .success(nfts))
//                } catch {
//                    continuation.resume(with: .failure(error))
//                }
//            }
//
//            self.operationQueue.addOperations(fetchNftsOperation.allOperations, waitUntilFinished: true)
//        }
    }
}

extension AlchemyNftFetchingService: NFTFetchingServiceProtocol {
    func fetchNfts(for wallet: MetaAccountModel) async throws -> [NFT] {
        guard let chains = try? await fetchSupportedChains() else {
            return []
        }

        let nfts = try await withThrowingTaskGroup(of: [NFT]?.self) { [weak self] group in
            guard let strongSelf = self else {
                return [NFT]()
            }

            for chain in chains {
                group.addTask {
                    let nfts = try? await strongSelf.fetchNfts(for: chain, wallet: wallet)
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

    func fetchCollections(for wallet: MetaAccountModel) async throws -> [NFTCollection] {
        guard let chains = try? await fetchSupportedChains() else {
            return []
        }

        let collections = try await withThrowingTaskGroup(of: [NFTCollection]?.self) { [weak self] group in
            guard let strongSelf = self else {
                return [NFTCollection]()
            }

            for chain in chains {
                group.addTask {
                    let collections = try? await strongSelf.fetchCollections(for: chain, wallet: wallet)
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
}
